import Foundation
import ServiceManagement
import Security

/// Gerencia a instalação e verificação da Helper Tool privilegiada
/// Baseado no HelperManager.swift do CoreAudioTapReal
class HelperInstallationManager: HelperInstallationManagerProtocol {
    
    // MARK: - Constants
    
    private static let helperIdentifier = "com.meetingrecorder.AudioCaptureHelper"
    private static let helperExecutableName = "AudioCaptureHelper"
    
    // MARK: - Properties
    
    private let logger = LoggingService.shared
    static let shared = HelperInstallationManager()
    
    // MARK: - Initialization
    
    private init() {
        logger.info("HelperInstallationManager inicializado", category: .audio)
    }
    
    // MARK: - HelperInstallationManagerProtocol
    
    func isHelperInstalled() async throws -> Bool {
        logger.debug("Verificando se Helper Tool está instalada", category: .audio)
        
        return await withCheckedContinuation { continuation in
            // Em ambiente de desenvolvimento, simular que não está instalada
            // para testar o fluxo de "instalação" via desenvolvimento
            let isDevEnvironment = !Bundle.main.bundlePath.hasSuffix(".app")
            
            if isDevEnvironment {
                logger.debug("Ambiente de desenvolvimento detectado - simulando Helper não instalada", category: .audio)
                continuation.resume(returning: false)
                return
            }
            
            // Verificar se a helper está registrada no launchd (produção)
            let helperInfo = SMJobCopyDictionary(
                kSMDomainSystemLaunchd,
                Self.helperIdentifier as CFString
            )
            
            let isInstalled = (helperInfo != nil)
            
            if let info = helperInfo {
                info.release()
            }
            
            logger.debug("Helper Tool instalada: \(isInstalled)", category: .audio)
            continuation.resume(returning: isInstalled)
        }
    }
    
    func installHelperIfNeeded() async throws -> Bool {
        logger.info("Verificando necessidade de instalar Helper Tool", category: .audio)
        
        // Primeiro verificar se já está instalada
        let isAlreadyInstalled = try await isHelperInstalled()
        if isAlreadyInstalled {
            logger.info("Helper Tool já está instalada", category: .audio)
            return true
        }
        
        // Verificar se estamos em ambiente de desenvolvimento
        let isDevEnvironment = !Bundle.main.bundlePath.hasSuffix(".app")
        
        if isDevEnvironment {
            logger.info("🔧 Ambiente de desenvolvimento: simulando instalação da Helper Tool", category: .audio)
            
            // Em desenvolvimento, apenas verificar se a Helper Tool existe e pode ser executada
            guard let helperPath = getHelperToolPath() else {
                logger.error("Helper Tool não encontrada para desenvolvimento", category: .audio)
                return false
            }
            
            // Verificar se é executável
            let fileManager = FileManager.default
            let isExecutable = fileManager.isExecutableFile(atPath: helperPath)
            
            if isExecutable {
                logger.info("✅ Helper Tool encontrada e executável em desenvolvimento: \(helperPath)", category: .audio)
                return true
            } else {
                logger.error("❌ Helper Tool não é executável: \(helperPath)", category: .audio)
                return false
            }
        }
        
        // Em produção, verificar requisitos para SMJobBless
        logger.info("Verificando requisitos para instalação via SMJobBless...", category: .audio)
        
        // Verificar se a aplicação está assinada
        guard isApplicationSigned() else {
            logger.warning("⚠️ Aplicação não está assinada - SMJobBless não funcionará", category: .audio)
            logger.info("🔧 Usando modo simulado em produção devido à falta de assinatura", category: .audio)
            throw XPCError.installationFailed("Aplicação não assinada adequadamente") // Retorna sucesso para usar modo simulado
        }
        
        // Verificar se Helper Tool existe no bundle
        guard let helperPath = getHelperToolPath() else {
            logger.error("Helper Tool não encontrada no bundle", category: .audio)
            throw XPCError.installationFailed("Helper Tool não encontrada no bundle")
        }
        
        // Verificar se Helper Tool está assinada
        guard isHelperToolSigned(at: helperPath) else {
            logger.warning("⚠️ Helper Tool não está assinada - SMJobBless não funcionará", category: .audio)
            logger.info("🔧 Usando modo simulado em produção devido à Helper Tool não assinada", category: .audio)
            throw XPCError.installationFailed("Helper Tool não assinada adequadamente") // Retorna sucesso para usar modo simulado
        }
        
        // Tentar instalar via SMJobBless
        logger.info("Instalando Helper Tool via SMJobBless...", category: .audio)
        
        return await withCheckedContinuation { continuation in
            do {
                // Criar autorização com direitos específicos
                let authRef = try self.createAuthorizationRefWithRights()
                
                logger.debug("Helper Tool path: \(helperPath)", category: .audio)
                
                // Instalar via SMJobBless
                var error: Unmanaged<CFError>?
                let success = SMJobBless(
                    kSMDomainSystemLaunchd,
                    Self.helperIdentifier as CFString,
                    authRef,
                    &error
                )
                
                if success {
                    logger.info("✅ Helper Tool instalada com sucesso via SMJobBless", category: .audio)
                    continuation.resume(returning: true)
                } else {
                    let errorDescription = error?.takeRetainedValue().localizedDescription ?? "Erro desconhecido"
                    logger.error("❌ SMJobBless falhou: \(errorDescription)", category: .audio)
                    
                    // Em caso de falha, usar modo simulado
                    logger.info("🔧 Fallback: usando modo simulado devido à falha do SMJobBless", category: .audio)
                    continuation.resume(returning: false)
                }
                
                // Limpar autorização
                AuthorizationFree(authRef, AuthorizationFlags())
                
            } catch {
                logger.error("❌ Erro durante instalação da Helper Tool", error: error, category: .audio)
                logger.info("🔧 Fallback: usando modo simulado devido ao erro", category: .audio)
                continuation.resume(returning: false) // Usar modo simulado em caso de erro
            }
        }
    }
    
    func checkHelperVersion() async throws -> String? {
        logger.debug("Verificando versão da Helper Tool", category: .audio)
        
        guard try await isHelperInstalled() else {
            return nil
        }
        
        // Tentar conectar e obter versão
        guard let connection = createXPCConnection() else {
            return nil
        }
        
        return await withCheckedContinuation { continuation in
            let helper = connection.remoteObjectProxyWithErrorHandler { error in
                self.logger.error("Erro ao conectar para verificar versão", error: error, category: .audio)
                continuation.resume(returning: nil)
            } as? AudioHelperProtocol
            
            helper?.getVersion { version in
                self.logger.debug("Versão da Helper Tool: \(version)", category: .audio)
                continuation.resume(returning: version)
            }
        }
    }
    
    func createXPCConnection() -> NSXPCConnection? {
        logger.debug("Criando conexão XPC com Helper Tool", category: .audio)
        
        // Em ambiente de desenvolvimento, usar um mock
        let isDevEnvironment = !Bundle.main.bundlePath.hasSuffix(".app")
        
        if isDevEnvironment {
            logger.info("🔧 Desenvolvimento: usando mock XPC (Core Audio Tap simulado)", category: .audio)
            // Retornar nil para indicar que deve usar fallback
            return nil
        }
        
        // Em produção, usar XPC real
        let connection = NSXPCConnection(machServiceName: Self.helperIdentifier, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: AudioHelperProtocol.self)
        
        connection.invalidationHandler = {
            self.logger.warning("Conexão XPC invalidada", category: .audio)
        }
        
        connection.interruptionHandler = {
            self.logger.warning("Conexão XPC interrompida", category: .audio)
        }
        
        connection.resume()
        
        logger.debug("Conexão XPC criada e ativada", category: .audio)
        return connection
    }
    
    // MARK: - Helper Methods
    
    private func createAuthorizationRef() throws -> AuthorizationRef {
        var authRef: AuthorizationRef?
        let status = AuthorizationCreate(nil, nil, [], &authRef)
        
        guard status == errSecSuccess, let auth = authRef else {
            throw XPCError.installationFailed("Falha ao criar autorização: \(status)")
        }
        
        return auth
    }
    
    private func createAuthorizationRefWithRights() throws -> AuthorizationRef {
        var authRef: AuthorizationRef?
        let status = AuthorizationCreate(nil, nil, [], &authRef)
        
        guard status == errSecSuccess, let auth = authRef else {
            throw XPCError.installationFailed("Falha ao criar autorização: \(status)")
        }
        
        // Preparar direitos específicos para SMJobBless
        let rightName = kSMRightBlessPrivilegedHelper
        
        return try rightName.withCString { rightNamePtr in
            var authItem = AuthorizationItem(
                name: rightNamePtr,
                valueLength: 0,
                value: nil,
                flags: 0
            )
            
            return try withUnsafeMutablePointer(to: &authItem) { authItemPtr in
                var authRights = AuthorizationRights(count: 1, items: authItemPtr)
                
                // Autorizar com os direitos específicos
                let authStatus = AuthorizationCopyRights(
                    auth,
                    &authRights,
                    nil,
                    [.interactionAllowed, .preAuthorize, .extendRights],
                    nil
                )
                
                if authStatus != errSecSuccess {
                    AuthorizationFree(auth, AuthorizationFlags())
                    throw XPCError.installationFailed("Falha ao obter direitos de autorização: \(authStatus)")
                }
                
                return auth
            }
        }
    }
    
    private func isApplicationSigned() -> Bool {
        guard let bundlePath = Bundle.main.bundlePath as String? else {
            return false
        }
        
        var staticCode: SecStaticCode?
        let createStatus = SecStaticCodeCreateWithPath(
            URL(fileURLWithPath: bundlePath) as CFURL,
            SecCSFlags(),
            &staticCode
        )
        
        guard createStatus == errSecSuccess, let code = staticCode else {
            return false
        }
        
        let checkStatus = SecStaticCodeCheckValidity(
            code,
            SecCSFlags(),
            nil
        )
        
        return checkStatus == errSecSuccess
    }
    
    private func isHelperToolSigned(at path: String) -> Bool {
        var staticCode: SecStaticCode?
        let createStatus = SecStaticCodeCreateWithPath(
            URL(fileURLWithPath: path) as CFURL,
            SecCSFlags(),
            &staticCode
        )
        
        guard createStatus == errSecSuccess, let code = staticCode else {
            return false
        }
        
        let checkStatus = SecStaticCodeCheckValidity(
            code,
            SecCSFlags(),
            nil
        )
        
        return checkStatus == errSecSuccess
    }
    
    private func getHelperToolPath() -> String? {
        let fileManager = FileManager.default
        
        // 1. Verificar no bundle da aplicação (produção)
        if let bundlePath = Bundle.main.bundlePath as String? {
            let helperPath = "\(bundlePath)/Contents/Library/LaunchServices/\(Self.helperExecutableName)"
            if fileManager.fileExists(atPath: helperPath) {
                logger.debug("Helper Tool encontrada no bundle: \(helperPath)", category: .audio)
                return helperPath
            }
        }
        
        // 2. Verificar no diretório HelperTools (desenvolvimento)
        let currentDir = fileManager.currentDirectoryPath
        let devHelperPath = "\(currentDir)/HelperTools/AudioCaptureHelper/\(Self.helperExecutableName)"
        if fileManager.fileExists(atPath: devHelperPath) {
            logger.debug("Helper Tool encontrada em desenvolvimento: \(devHelperPath)", category: .audio)
            return devHelperPath
        }
        
        // 3. Verificar caminhos relativos ao executável
        if let executablePath = Bundle.main.executablePath {
            let executableDir = (executablePath as NSString).deletingLastPathComponent
            
            // Caminho relativo para ambiente de desenvolvimento Swift PM
            let relativeHelperPath = "\(executableDir)/../../../HelperTools/AudioCaptureHelper/\(Self.helperExecutableName)"
            if fileManager.fileExists(atPath: relativeHelperPath) {
                logger.debug("Helper Tool encontrada via caminho relativo: \(relativeHelperPath)", category: .audio)
                return relativeHelperPath
            }
        }
        
        logger.error("Helper Tool não encontrada em nenhum caminho", category: .audio)
        return nil
    }
    
    // MARK: - Installation Status
    
    func getInstallationStatus() async -> HelperInstallationStatus {
        do {
            let isInstalled = try await isHelperInstalled()
            let version = try await checkHelperVersion()
            
            return HelperInstallationStatus(
                isInstalled: isInstalled,
                version: version,
                canInstall: true,
                lastError: nil
            )
        } catch {
            logger.error("Erro ao verificar status de instalação", error: error, category: .audio)
            
            return HelperInstallationStatus(
                isInstalled: false,
                version: nil,
                canInstall: false,
                lastError: error
            )
        }
    }
}

// MARK: - Objective-C Protocol Import

// Importar o protocolo Objective-C para uso em Swift
@objc protocol AudioHelperProtocol {
    func getVersion(withReply reply: @escaping (String) -> Void)
    func startAudioCapture(forPID processID: pid_t, withReply reply: @escaping (Bool, Error?) -> Void)
    func stopAudioCapture(withReply reply: @escaping (Bool, Error?) -> Void)
    func getCaptureStatus(withReply reply: @escaping (Bool, String?) -> Void)
}