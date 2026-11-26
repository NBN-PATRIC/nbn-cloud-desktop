/*
 * NBN Cloud: arquivos virtuais no macOS pela extensão File Provider. Ver nbnfileprovider_mac.h.
 *
 * Compilado com ARC (-fobjc-arc, src/gui/CMakeLists.txt).
 *
 * Baseado no ownCloud Desktop (GPLv2 ou posterior). Este arquivo segue a mesma licença.
 */
#include "gui/macOS/nbnfileprovider_mac.h"

#include "account.h"
#include "gui/accountmanager.h"
#include "common/utility.h"
#include "configfile.h"
#include "libsync/creds/httpcredentials.h"
#include "libsync/nbnmacfileprovider.h"

#include <QDesktopServices>
#include <QLoggingCategory>
#include <QMessageBox>
#include <QPointer>
#include <QPushButton>
#include <QTimer>
#include <QUrl>

#import <FileProvider/FileProvider.h>
#import <Foundation/Foundation.h>

#import "gui/macOS/ClientCommunicationProtocol.h"

#include <chrono>

using namespace std::chrono_literals;

Q_LOGGING_CATEGORY(lcNbnFileProvider, "nbn.gui.fileprovider", QtInfoMsg)

// Nome do serviço XPC exposto pela extensão (NextcloudFileProviderKit, FileProviderExtension.serviceName).
static NSString *const kNbnServicoXpc = @"com.nextcloud.desktopclient.ClientCommunicationService";

// Serviço e conexão retidos: liberados, a conexão cai e a extensão perde a conta.
@interface NBNFileProviderConexao : NSObject
@property (nonatomic, strong) NSFileProviderService *servico;
@property (nonatomic, strong) NSXPCConnection *conexao;
@end

@implementation NBNFileProviderConexao
@end

namespace {

QString domainIdFor(const OCC::AccountPtr &account)
{
    return account->uuid().toString(QUuid::WithoutBraces);
}

NSFileProviderDomain *domainFor(const OCC::AccountPtr &account)
{
    // o nome aparece no Finder (barra lateral e ~/Library/CloudStorage/NBN Cloud-<nome>)
    return [[NSFileProviderDomain alloc] initWithIdentifier:domainIdFor(account).toNSString()
                                                displayName:account->displayNameWithHost().toNSString()];
}

void naThreadPrincipal(void (^bloco)(void))
{
    dispatch_async(dispatch_get_main_queue(), bloco);
}

// Contas com arquivos virtuais, guardadas na configuração do app. O macOS remove o domínio quando o app some do
// disco (atualização arrastando por cima, reinstalação): com a marca, o app recria o domínio ao abrir.
const QString grupoMarca = QStringLiteral("NbnFileProvider");

bool contaMarcada(const QString &dominioId)
{
    auto s = OCC::ConfigFile::makeQSettings();
    return s.value(grupoMarca + QLatin1Char('/') + dominioId, false).toBool();
}

void marcarConta(const QString &dominioId, bool marcada)
{
    auto s = OCC::ConfigFile::makeQSettings();
    if (marcada) {
        s.setValue(grupoMarca + QLatin1Char('/') + dominioId, true);
    } else {
        s.remove(grupoMarca + QLatin1Char('/') + dominioId);
    }
    s.sync();
}

} // namespace

namespace OCC {

struct NbnFileProviderMac::Private
{
    QSet<QString> dominios; // identificadores dos domínios registrados no sistema
    bool dominiosCarregados = false;
    QSet<QString> conectando;
    QSet<QString> avisoAtivacaoMostrado;
    NSMutableDictionary<NSString *, NBNFileProviderConexao *> *conexoes = [NSMutableDictionary dictionary];
};

NbnFileProviderMac *NbnFileProviderMac::instance()
{
    static NbnFileProviderMac *instancia = new NbnFileProviderMac(qApp);
    return instancia;
}

bool NbnFileProviderMac::isAvailable()
{
    return nbnMacFileProviderAvailable();
}

void NbnFileProviderMac::openSystemSettings()
{
    QDesktopServices::openUrl(
        QUrl(QStringLiteral("x-apple.systempreferences:com.apple.ExtensionsPreferences?extensionPointIdentifier=com.apple.fileprovider-nonui")));
}

NbnFileProviderMac::NbnFileProviderMac(QObject *parent)
    : QObject(parent)
    , d(new Private)
{
    // reentrega periódica: barata (a extensão ignora a mesma conta repetida) e cobre quedas silenciosas
    auto *reentrega = new QTimer(this);
    reentrega->setInterval(10min);
    connect(reentrega, &QTimer::timeout, this, [this] {
        for (const auto &conta : AccountManager::instance()->accounts()) {
            configure(conta);
        }
    });
    reentrega->start();
    loadDomains();
}

NbnFileProviderMac::~NbnFileProviderMac()
{
    for (NBNFileProviderConexao *c in d->conexoes.allValues) {
        [c.conexao invalidate];
    }
    delete d;
}

void NbnFileProviderMac::loadDomains()
{
    QPointer<NbnFileProviderMac> eu(this);
    [NSFileProviderManager getDomainsWithCompletionHandler:^(NSArray<NSFileProviderDomain *> *domains, NSError *error) {
        QSet<QString> ids;
        for (NSFileProviderDomain *dominio in domains) {
            ids.insert(QString::fromNSString(dominio.identifier));
        }
        if (error) {
            qCWarning(lcNbnFileProvider) << "Falha ao listar os domínios:" << QString::fromNSString(error.localizedDescription);
        }
        naThreadPrincipal(^{
            if (!eu) {
                return;
            }
            eu->d->dominios = ids;
            eu->d->dominiosCarregados = true;
            qCInfo(lcNbnFileProvider) << "Domínios do File Provider:" << ids;
            for (const auto &conta : AccountManager::instance()->accounts()) {
                const QString dominioId = domainIdFor(conta->account());
                if (!ids.contains(dominioId) && contaMarcada(dominioId)) {
                    qCInfo(lcNbnFileProvider) << "Domínio sumiu (app reinstalado ou atualizado), recriando:" << dominioId;
                    eu->enableForAccount(conta);
                    continue;
                }
                eu->configure(conta);
            }
        });
    }];
}

bool NbnFileProviderMac::hasDomain(const AccountStatePtr &accountState) const
{
    return accountState && d->dominios.contains(domainIdFor(accountState->account()));
}

void NbnFileProviderMac::accountAdded(const AccountStatePtr &accountState)
{
    if (!accountState) {
        return;
    }
    connect(accountState.data(), &AccountState::isConnectedChanged, this, [this, accountState] { configure(accountState); });
    connect(accountState->account().data(), &Account::credentialsFetched, this, [this, accountState] { configure(accountState); });
    configure(accountState);
}

void NbnFileProviderMac::enableForAccount(const AccountStatePtr &accountState)
{
    if (!accountState || !isAvailable()) {
        return;
    }
    const QString dominioId = domainIdFor(accountState->account());
    NSFileProviderDomain *dominio = domainFor(accountState->account());
    QPointer<NbnFileProviderMac> eu(this);
    QPointer<AccountState> conta(accountState);
    [NSFileProviderManager addDomain:dominio completionHandler:^(NSError *error) {
        const QString erro = error ? QString::fromNSString(error.localizedDescription) : QString();
        naThreadPrincipal(^{
            if (!eu) {
                return;
            }
            if (!erro.isEmpty()) {
                qCWarning(lcNbnFileProvider) << "Falha ao registrar o domínio" << dominioId << erro;
                return;
            }
            qCInfo(lcNbnFileProvider) << "Domínio registrado" << dominioId;
            marcarConta(dominioId, true);
            eu->d->dominios.insert(dominioId);
            eu->configure(conta);
            QTimer::singleShot(3s, eu, [eu, conta] {
                if (eu) {
                    eu->checkUserEnabled(conta);
                }
            });
        });
    }];
}

void NbnFileProviderMac::configure(const AccountStatePtr &accountState)
{
    if (!accountState || !d->dominiosCarregados) {
        return;
    }
    const auto account = accountState->account();
    const QString dominioId = domainIdFor(account);
    if (!d->dominios.contains(dominioId) || !accountState->isConnected()) {
        return;
    }
    if (d->conexoes[dominioId.toNSString()].conexao) {
        sendAccount(accountState);
        return;
    }
    if (d->conectando.contains(dominioId)) {
        return;
    }
    d->conectando.insert(dominioId);

    NSFileProviderManager *gerente = [NSFileProviderManager managerForDomain:domainFor(account)];
    QPointer<NbnFileProviderMac> eu(this);
    QPointer<AccountState> conta(accountState);
    NSString *chave = dominioId.toNSString();
    [gerente getServiceWithName:kNbnServicoXpc
                 itemIdentifier:NSFileProviderRootContainerItemIdentifier
              completionHandler:^(NSFileProviderService *servico, NSError *error) {
                  if (!servico) {
                      const QString erro = error ? QString::fromNSString(error.localizedDescription) : QString();
                      naThreadPrincipal(^{
                          qCWarning(lcNbnFileProvider) << "Serviço XPC da extensão indisponível para" << dominioId << erro;
                          if (eu) {
                              eu->d->conectando.remove(dominioId);
                          }
                      });
                      return;
                  }
                  [servico getFileProviderConnectionWithCompletionHandler:^(NSXPCConnection *conexao, NSError *error2) {
                      if (!conexao) {
                          const QString erro = error2 ? QString::fromNSString(error2.localizedDescription) : QString();
                          naThreadPrincipal(^{
                              qCWarning(lcNbnFileProvider) << "Sem conexão XPC com a extensão para" << dominioId << erro;
                              if (eu) {
                                  eu->d->conectando.remove(dominioId);
                              }
                          });
                          return;
                      }
                      conexao.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(ClientCommunicationProtocol)];
                      void (^caiu)(void) = ^{
                          naThreadPrincipal(^{
                              if (eu) {
                                  eu->connectionLost(dominioId);
                              }
                          });
                      };
                      conexao.invalidationHandler = caiu;
                      conexao.interruptionHandler = caiu;
                      [conexao resume];
                      naThreadPrincipal(^{
                          if (!eu) {
                              [conexao invalidate];
                              return;
                          }
                          NBNFileProviderConexao *retida = [NBNFileProviderConexao new];
                          retida.servico = servico;
                          retida.conexao = conexao;
                          eu->d->conexoes[chave] = retida;
                          eu->d->conectando.remove(dominioId);
                          qCInfo(lcNbnFileProvider) << "Conectado à extensão do domínio" << dominioId;
                          eu->sendAccount(conta);
                      });
                  }];
              }];
}

void NbnFileProviderMac::sendAccount(const AccountStatePtr &accountState)
{
    if (!accountState) {
        return;
    }
    const auto account = accountState->account();
    const QString dominioId = domainIdFor(account);
    NBNFileProviderConexao *retida = d->conexoes[dominioId.toNSString()];
    if (!retida.conexao) {
        return;
    }
    auto *credenciais = qobject_cast<HttpCredentials *>(account->credentials());
    if (!credenciais || credenciais->password().isEmpty()) {
        qCInfo(lcNbnFileProvider) << "Credencial ainda indisponível para" << dominioId;
        return;
    }
    if (credenciais->isUsingOAuth()) {
        // a extensão autentica por usuário e senha (Basic); token OAuth/OIDC fica para a fase do Infinite Scale
        qCWarning(lcNbnFileProvider) << "Conta com OAuth: arquivos virtuais do macOS ainda não suportam token" << dominioId;
        return;
    }
    // o kit monta <servidor>/remote.php/dav/...: com a barra final do url() da conta sairia "//remote.php" e o
    // servidor responderia uma página em vez do WebDAV ("Invalid data format")
    QString servidor = account->url().toString();
    while (servidor.endsWith(QLatin1Char('/'))) {
        servidor.chop(1);
    }
    id<ClientCommunicationProtocol> proxy = [retida.conexao remoteObjectProxyWithErrorHandler:^(NSError *error) {
        const QString erro = QString::fromNSString(error.localizedDescription);
        naThreadPrincipal(^{
            qCWarning(lcNbnFileProvider) << "Erro XPC ao entregar a conta" << dominioId << erro;
        });
    }];
    [proxy configureAccountWithUser:credenciais->user().toNSString()
                             userId:account->davUser().toNSString()
                          serverUrl:servidor.toNSString()
                           password:credenciais->password().toNSString()
                          userAgent:QString::fromUtf8(Utility::userAgentString()).toNSString()];
    qCInfo(lcNbnFileProvider) << "Conta entregue à extensão do domínio" << dominioId;
}

void NbnFileProviderMac::connectionLost(const QString &domainId)
{
    qCInfo(lcNbnFileProvider) << "Conexão com a extensão caiu, reconectando:" << domainId;
    [d->conexoes removeObjectForKey:domainId.toNSString()];
    QTimer::singleShot(5s, this, [this, domainId] {
        for (const auto &conta : AccountManager::instance()->accounts()) {
            if (domainIdFor(conta->account()) == domainId) {
                configure(conta);
            }
        }
    });
}

void NbnFileProviderMac::checkUserEnabled(const AccountStatePtr &accountState)
{
    if (!accountState) {
        return;
    }
    const QString dominioId = domainIdFor(accountState->account());
    QPointer<NbnFileProviderMac> eu(this);
    [NSFileProviderManager getDomainsWithCompletionHandler:^(NSArray<NSFileProviderDomain *> *domains, NSError *erroLista) {
        (void)erroLista;
        bool ligado = true;
        for (NSFileProviderDomain *dominio in domains) {
            if (QString::fromNSString(dominio.identifier) != dominioId) {
                continue;
            }
            // userEnabled (macOS 15+): o usuário precisa ligar cada provedor novo uma vez nos Ajustes
            @try {
                id valor = [dominio valueForKey:@"userEnabled"];
                if ([valor respondsToSelector:@selector(boolValue)]) {
                    ligado = [valor boolValue];
                }
            } @catch (NSException *excecao) {
                (void)excecao;
            }
        }
        naThreadPrincipal(^{
            if (!eu || ligado || eu->d->avisoAtivacaoMostrado.contains(dominioId)) {
                return;
            }
            eu->d->avisoAtivacaoMostrado.insert(dominioId);
            auto *aviso = new QMessageBox(QMessageBox::Information, QObject::tr("Ative o NBN Cloud no Finder"),
                QObject::tr("Para os seus arquivos aparecerem no Finder sem ocupar espaço no Mac, ligue o NBN Cloud uma vez em "
                            "Ajustes do Sistema > Geral > Itens de Início e Extensões > Provedores de Arquivos."));
            QPushButton *abrir = aviso->addButton(QObject::tr("Abrir Ajustes"), QMessageBox::AcceptRole);
            aviso->addButton(QObject::tr("Depois"), QMessageBox::RejectRole);
            aviso->setAttribute(Qt::WA_DeleteOnClose);
            QObject::connect(aviso, &QMessageBox::buttonClicked, aviso, [abrir](QAbstractButton *botao) {
                if (botao == abrir) {
                    NbnFileProviderMac::openSystemSettings();
                }
            });
            aviso->show();
            aviso->raise();
        });
    }];
}

void NbnFileProviderMac::accountRemoved(const AccountStatePtr &accountState)
{
    if (!accountState) {
        return;
    }
    const QString dominioId = domainIdFor(accountState->account());
    marcarConta(dominioId, false);
    if (!d->dominios.contains(dominioId)) {
        return;
    }
    d->dominios.remove(dominioId);
    NSFileProviderDomain *dominio = domainFor(accountState->account());
    void (^remover)(void) = ^{
        [NSFileProviderManager removeDomain:dominio completionHandler:^(NSError *error) {
            const QString erro = error ? QString::fromNSString(error.localizedDescription) : QString();
            naThreadPrincipal(^{
                if (erro.isEmpty()) {
                    qCInfo(lcNbnFileProvider) << "Domínio removido" << dominioId;
                } else {
                    qCWarning(lcNbnFileProvider) << "Falha ao remover o domínio" << dominioId << erro;
                }
            });
        }];
    };
    NBNFileProviderConexao *retida = d->conexoes[dominioId.toNSString()];
    [d->conexoes removeObjectForKey:dominioId.toNSString()];
    if (!retida.conexao) {
        remover();
        return;
    }
    // primeiro a extensão apaga a senha que guardou no chaveiro, depois o domínio sai
    id<ClientCommunicationProtocol> proxy = [retida.conexao remoteObjectProxyWithErrorHandler:^(NSError *erroXpc) {
        (void)erroXpc;
        remover();
    }];
    [proxy deletePasswordWithCompletionHandler:^(BOOL apagou) {
        (void)apagou;
        [retida.conexao invalidate];
        remover();
    }];
}

} // namespace OCC
