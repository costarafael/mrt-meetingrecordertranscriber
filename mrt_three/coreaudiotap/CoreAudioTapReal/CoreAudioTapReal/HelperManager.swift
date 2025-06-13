import Foundation
import ServiceManagement
import Security

class HelperManager {
    static let shared = HelperManager()
    
    private let helperLabel = "com.empresa.CoreAudioTapReal.AudioCaptureHelper"
    
    private init() {}
    
    func isHelperInstalled() async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            // Tenta conectar via XPC para verificar se está instalada e funcionando
            let connection = NSXPCConnection(machServiceName: helperLabel, options: .privileged)
            connection.remoteObjectInterface = NSXPCInterface(with: AudioHelperProtocol.self)
            
            connection.invalidationHandler = {
                continuation.resume(returning: false)
            }
            
            connection.interruptionHandler = {
                continuation.resume(returning: false)
            }
            
            connection.resume()
            
            guard let helper = connection.remoteObjectProxyWithErrorHandler({ error in
                continuation.resume(returning: false)
            }) as? AudioHelperProtocol else {
                continuation.resume(returning: false)
                return
            }
            
            // Testa se consegue obter versão da helper
            helper.getVersionWithReply { version in
                connection.invalidate()
                continuation.resume(returning: !version.isEmpty)
            }
        }
    }
    
    func installHelperIfNeeded(completion: @escaping (Result<Void, Error>) -> Void) {
        print("🔧 Iniciando instalação da helper tool...")
        
        // Primeiro obtém autorização
        var authRef: AuthorizationRef?
        var authStatus = AuthorizationCreate(nil, nil, [], &authRef)
        
        guard authStatus == errAuthorizationSuccess else {
            let error = NSError(
                domain: NSOSStatusErrorDomain,
                code: Int(authStatus),
                userInfo: [NSLocalizedDescriptionKey: "Falha ao criar autorização"]
            )
            completion(.failure(error))
            return
        }
        
        defer {
            if let authRef = authRef {
                AuthorizationFree(authRef, [])
            }
        }
        
        // Solicita direitos específicos para SMJobBless
        let rightName = kSMRightBlessPrivilegedHelper
        rightName.withCString { rightNamePtr in
            var authItem = AuthorizationItem(
                name: rightNamePtr,
                valueLength: 0,
                value: nil,
                flags: 0
            )
            var authRights = AuthorizationRights(count: 1, items: &authItem)
            let flags: AuthorizationFlags = [.interactionAllowed, .preAuthorize, .extendRights]
            
            authStatus = AuthorizationCopyRights(authRef!, &authRights, nil, flags, nil)
        }
        
        guard authStatus == errAuthorizationSuccess else {
            let error: NSError
            
            if authStatus == errAuthorizationCanceled {
                error = NSError(
                    domain: NSOSStatusErrorDomain,
                    code: Int(authStatus),
                    userInfo: [NSLocalizedDescriptionKey: "Instalação cancelada pelo usuário"]
                )
            } else {
                error = NSError(
                    domain: NSOSStatusErrorDomain,
                    code: Int(authStatus),
                    userInfo: [NSLocalizedDescriptionKey: "Falha na autorização: \(authStatus)"]
                )
            }
            completion(.failure(error))
            return
        }
        
        print("🔐 Autorização obtida, chamando SMJobBless...")
        
        // Chama SMJobBless para instalar a helper
        var cfError: Unmanaged<CFError>?
        let blessStatus = SMJobBless(
            kSMDomainSystemLaunchd,
            helperLabel as CFString,
            authRef,
            &cfError
        )
        
        if blessStatus {
            print("✅ Helper tool instalada com sucesso")
            completion(.success(()))
        } else {
            let error = cfError?.takeRetainedValue() as Error? ?? NSError(
                domain: "com.empresa.SMJobBlessError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "SMJobBless falhou por razão desconhecida"]
            )
            
            let nsError = error as NSError
            print("❌ SMJobBless falhou - Código: \(nsError.code), Descrição: \(nsError.localizedDescription)")
            
            // Mapeia erros comuns do SMJobBless
            let mappedError = mapSMJobBlessError(nsError)
            completion(.failure(mappedError))
        }
    }
    
    private func mapSMJobBlessError(_ error: NSError) -> NSError {
        let code = error.code
        var description = error.localizedDescription
        var reason = ""
        
        switch code {
        case 3: // kSMErrorInvalidSignature
            description = "Assinatura de código inválida"
            reason = "Verifique se ambos os alvos estão assinados com Developer ID válido"
        case 4: // kSMErrorAuthorizationFailure
            description = "Falha na autorização"
            reason = "Problema com direitos de autorização do SMJobBless"
        case 5: // kSMErrorToolNotValid
            description = "Helper tool não encontrada ou inválida"
            reason = "Verifique se a helper está em Contents/Library/LaunchServices"
        case 8: // kSMErrorJobPlistNotFound
            description = "launchd.plist não encontrado"
            reason = "Verifique os flags do linker para embedar o plist"
        case 10: // kSMErrorInvalidPlist
            description = "Info.plist ou launchd.plist inválido"
            reason = "Verifique a sintaxe XML e chaves requeridas"
        case -60006: // errAuthorizationCanceled
            description = "Instalação cancelada pelo usuário"
            reason = "Usuário cancelou o diálogo de autenticação"
        default:
            description = "Erro do SMJobBless: \(code)"
            reason = "Consulte logs do Console.app para mais detalhes"
        }
        
        return NSError(
            domain: error.domain,
            code: code,
            userInfo: [
                NSLocalizedDescriptionKey: description,
                NSLocalizedFailureReasonErrorKey: reason
            ]
        )
    }
}