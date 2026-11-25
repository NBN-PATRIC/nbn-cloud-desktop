// NBN Cloud: extensão File Provider do macOS.
// A classe principal é NextcloudFileProviderKit.FileProviderExtension (Info.plist, NSExtensionPrincipalClass).
// Esta referência garante que o vinculador mantenha a classe no binário da extensão.
import NextcloudFileProviderKit

let classePrincipalDaExtensao: AnyClass = FileProviderExtension.self
