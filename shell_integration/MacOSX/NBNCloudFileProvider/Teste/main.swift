// NBN Cloud: app de teste da extensão File Provider (fase 1). Faz o papel que o app principal fará:
// registra o domínio e entrega a conta à extensão pelo canal XPC do NextcloudFileProviderKit.
//
//   NBNCloudFPTeste add                                   registra o domínio (pasta no Finder)
//   NBNCloudFPTeste config <servidor> <usuario> <arquivo> entrega a conta; a senha vem do arquivo, que é apagado
//   NBNCloudFPTeste status                                lista os domínios e a pasta
//   NBNCloudFPTeste remove                                esquece a conta (apaga a senha guardada) e remove o domínio
import FileProvider
import Foundation
import NextcloudFileProviderXPC

let dominio = NSFileProviderDomain(identifier: NSFileProviderDomainIdentifier("nbn-teste"), displayName: "NBN Cloud (teste)")
let servico = NSFileProviderServiceName("com.nextcloud.desktopclient.ClientCommunicationService")

func esperar(_ segundos: Double = 60, _ corpo: (@escaping () -> Void) -> Void) {
    let sem = DispatchSemaphore(value: 0)
    corpo { sem.signal() }
    if sem.wait(timeout: .now() + segundos) == .timedOut { print("tempo esgotado") }
}

// O serviço e a conexão precisam ficar vivos: liberados, a conexão cai e o kit cria outra instância da extensão,
// que não tem a conta (a conta fica na instância; o app principal a reentrega a cada conexão, como no Nextcloud).
var servicoRetido: NSFileProviderService?
var conexaoRetida: NSXPCConnection?

func comExtensao(manterSegundos: Double = 0, _ uso: @escaping (ClientCommunicationProtocol, @escaping () -> Void) -> Void) {
    guard let gerente = NSFileProviderManager(for: dominio) else { print("domínio não registrado: rode add"); return }
    esperar { pronto in
        gerente.getService(named: servico, for: .rootContainer) { serv, erro in
            guard let serv else { print("serviço XPC indisponível:", erro.map { "\($0)" } ?? "-"); pronto(); return }
            servicoRetido = serv
            serv.getFileProviderConnection { conexao, erro in
                guard let conexao else { print("sem conexão XPC:", erro.map { "\($0)" } ?? "-"); pronto(); return }
                conexaoRetida = conexao
                conexao.remoteObjectInterface = NSXPCInterface(with: ClientCommunicationProtocol.self)
                conexao.resume()
                let proxy = conexao.remoteObjectProxyWithErrorHandler { e in print("erro XPC:", e); pronto() }
                guard let ext = proxy as? ClientCommunicationProtocol else { print("proxy inválido"); pronto(); return }
                uso(ext) { pronto() }
            }
        }
    }
    if manterSegundos > 0 {
        print("conexão mantida por \(Int(manterSegundos)) s"); fflush(stdout)
        Thread.sleep(forTimeInterval: manterSegundos)
    }
    conexaoRetida?.invalidate()
    conexaoRetida = nil
    servicoRetido = nil
}

let args = Array(CommandLine.arguments.dropFirst())
switch args.first ?? "status" {
    case "add":
    esperar { pronto in NSFileProviderManager.add(dominio) { e in print("add:", e.map { "\($0)" } ?? "ok"); pronto() } }
    case "config":
    guard args.count >= 4, let senha = try? String(contentsOfFile: args[3], encoding: .utf8) else {
        print("uso: config <servidor> <usuario> <arquivo-com-a-senha> [segundos com a conexão aberta]"); exit(2)
    }
    try? FileManager.default.removeItem(atPath: args[3])
    let manter = args.count >= 5 ? Double(args[4]) ?? 0 : 0
    comExtensao(manterSegundos: manter) { ext, fim in
        ext.configureAccount(withUser: args[2], userId: args[2], serverUrl: args[1],
                             password: senha.trimmingCharacters(in: .whitespacesAndNewlines), userAgent: "NBN Cloud FP teste")
        // configureAccount não responde: esta chamada com resposta garante que a anterior chegou
        ext.getFileProviderDomainIdentifier { id, erro in print("conta entregue ao domínio:", id, erro.map { "\($0)" } ?? ""); fim() }
    }
    esperar { pronto in NSFileProviderManager(for: dominio)?.signalEnumerator(for: .workingSet) { e in print("signal:", e.map { "\($0)" } ?? "ok"); pronto() } }
    case "remove":
    comExtensao { ext, fim in ext.deletePassword { apagou in print("senha apagada:", apagou); fim() } }
    esperar { pronto in NSFileProviderManager.remove(dominio) { e in print("remove:", e.map { "\($0)" } ?? "ok"); pronto() } }
    default:
    esperar { pronto in
        NSFileProviderManager.getDomainsWithCompletionHandler { d, e in
            print("domínios:", d.map { "\($0.identifier.rawValue)=\($0.displayName)" }, e.map { "\($0)" } ?? ""); pronto()
        }
    }
}
if let gerente = NSFileProviderManager(for: dominio), args.first != "remove" {
    esperar(10) { pronto in gerente.getUserVisibleURL(for: .rootContainer) { u, _ in print("pasta:", u?.path ?? "-"); pronto() } }
}
