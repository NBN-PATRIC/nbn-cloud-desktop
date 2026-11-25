"""Ajustes do NBN Cloud no NextcloudFileProviderKit baixado pelo CI (LGPL-3.0-or-later; as mudanças seguem a licença).

Uso: python3 aplicar.py <pasta do NextcloudFileProviderKit>

1. Pasta de dados sem grupo de apps. O kit guarda banco e logs no contêiner do grupo de apps
   (NSExtensionFileProviderDocumentGroup). Sem conta de desenvolvedor da Apple o grupo não é validado e o macOS 15+
   pergunta ao usuário se o app "deseja acessar dados de outros apps" (de novo a cada versão). Sem a chave no
   Info.plist, o kit passa a usar a pasta de suporte da própria extensão (dentro do sandbox dela): nada a perguntar.
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
