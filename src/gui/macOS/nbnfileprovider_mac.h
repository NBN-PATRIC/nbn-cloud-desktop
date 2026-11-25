/*
 * NBN Cloud: arquivos virtuais no macOS pela extensão File Provider (shell_integration/MacOSX/NBNCloudFileProvider).
 *
 * Para cada conta com arquivos virtuais há um domínio do File Provider (identificador = UUID da conta). O app
 * principal registra o domínio, mantém aberta a conexão XPC com a extensão e entrega a conta a cada (re)conexão:
 * a extensão (NextcloudFileProviderKit) guarda a conta só na instância e não a relê do chaveiro.
 *
 * Baseado no ownCloud Desktop (GPLv2 ou posterior). Este arquivo segue a mesma licença.
 */
#pragma once

#include "gui/accountstate.h"

#include <QObject>
#include <QSet>
#include <QString>

namespace OCC {

  class NbnFileProviderMac : public QObject
  {
    Q_OBJECT

    public:
    static NbnFileProviderMac *instance();

    /// macOS 13 ou mais novo e a extensão dentro do app.
    static bool isAvailable();

    /// Abre os Ajustes do Sistema na lista de provedores de arquivos, onde o usuário liga o NBN Cloud.
    static void openSystemSettings();

    /// O assistente escolheu arquivos virtuais para esta conta: registra o domínio e entrega a conta.
    void enableForAccount(const AccountStatePtr &accountState);

    /// Conta carregada ou criada: entrega a conta à extensão sempre que conectar ou trocar a credencial.
    void accountAdded(const AccountStatePtr &accountState);

    /// Conta removida: apaga a senha guardada pela extensão e remove o domínio (a pasta some do Finder).
    void accountRemoved(const AccountStatePtr &accountState);

    /// A conta usa arquivos virtuais (tem domínio registrado).
    bool hasDomain(const AccountStatePtr &accountState) const;

    private:
    explicit NbnFileProviderMac(QObject *parent = nullptr);
    ~NbnFileProviderMac() override;

    void loadDomains();
    void configure(const AccountStatePtr &accountState);
    void sendAccount(const AccountStatePtr &accountState);
    void connectionLost(const QString &domainId);
    void checkUserEnabled(const AccountStatePtr &accountState);

    struct Private;
    Private *d;
  };

} // namespace OCC
