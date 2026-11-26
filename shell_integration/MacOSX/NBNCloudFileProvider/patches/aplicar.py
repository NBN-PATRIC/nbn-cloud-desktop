"""Ajustes do NBN Cloud no NextcloudFileProviderKit baixado pelo CI (LGPL-3.0-or-later; as mudanças seguem a licença).

Uso: python3 aplicar.py <pasta do NextcloudFileProviderKit>

1. Pasta de dados sem grupo de apps. O kit guarda banco e logs no contêiner do grupo de apps
   (NSExtensionFileProviderDocumentGroup). Sem conta de desenvolvedor da Apple o grupo não é validado e o macOS 15+
   pergunta ao usuário se o app "deseja acessar dados de outros apps" (de novo a cada versão). Sem a chave no
   Info.plist, o kit passa a usar a pasta de suporte da própria extensão (dentro do sandbox dela): nada a perguntar.
2. Conta restaurada em cada instância. O kit guarda servidor, usuário e id na configuração da extensão e a senha no
   chaveiro quando recebe a conta, mas só a usa na instância que a recebeu. O macOS cria instâncias novas da extensão
   (às vezes no mesmo processo, sem derrubar a conexão XPC do app), que ficavam sem conta e respondiam "você precisa
   autenticar" (FP -1000) ao enviar arquivo. Agora cada instância nova restaura a conta guardada.
"""
import pathlib
import sys

kit = pathlib.Path(sys.argv[1])
alvo = kit / "Sources/NextcloudFileProviderKit/Extensions/FileManager+applicationGroupContainer.swift"
texto = alvo.read_text(encoding="utf-8")
antes = """        guard let appGroupIdentifier = extensionDictionary["NSExtensionFileProviderDocumentGroup"] as? String else {
            return nil
        }"""
depois = """        guard let appGroupIdentifier = extensionDictionary["NSExtensionFileProviderDocumentGroup"] as? String else {
            // NBN Cloud: sem grupo de apps (assinatura sem conta Apple), usa a pasta da própria extensão
            return urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        }"""
if antes not in texto:
    sys.exit(f"trecho não encontrado em {alvo}: o kit mudou, revisar o ajuste")
alvo.write_text(texto.replace(antes, depois), encoding="utf-8")
print("ajuste 1 aplicado:", alvo.name)

alvo2 = kit / "Sources/NextcloudFileProviderKit/Extension/FileProviderExtension.swift"
texto2 = alvo2.read_text(encoding="utf-8")
antes2 = """        keychain = Keychain(domain: domain, log: log)
        super.init()
        observeBlockSync()
    }"""
depois2 = """        keychain = Keychain(domain: domain, log: log)
        super.init()
        observeBlockSync()
        // NBN Cloud: cada instância nova restaura a conta guardada (servidor, usuário e id na configuração, senha no
        // chaveiro); o macOS cria instâncias novas e o app principal nem sempre percebe
        if let servidor = config.serverUrl, let usuario = config.user, let usuarioId = config.userId,
           let senha = keychain.getPassword(for: usuario) {
            logger.info("NBN Cloud: restaurando a conta guardada na instância nova.")
            setupDomainAccount(user: usuario, userId: usuarioId, serverUrl: servidor, password: senha)
        }
    }"""
if antes2 not in texto2:
    sys.exit(f"trecho não encontrado em {alvo2}: o kit mudou, revisar o ajuste 2")
alvo2.write_text(texto2.replace(antes2, depois2), encoding="utf-8")
print("ajuste 2 aplicado:", alvo2.name)
