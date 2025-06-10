import Foundation
import AVFoundation
import ScreenCaptureKit
import OSLog

/// Service especializado para gerenciamento de permissões de áudio
class AudioPermissionManager {
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "AudioRecording", category: "PermissionManager")
    
    // MARK: - Public Methods
    
    /// Solicitar permissão de microfone
    /// - Returns: True se a permissão foi concedida
    func requestMicrophonePermission() async -> Bool {
        logger.info("🔐 Solicitando permissão de microfone...")
        
        return await withCheckedContinuation { continuation in
            let currentStatus = AVCaptureDevice.authorizationStatus(for: .audio)
            
            switch currentStatus {
            case .authorized:
                logger.info("✅ Permissão de microfone já concedida")
                continuation.resume(returning: true)
                
            case .notDetermined:
                logger.info("❓ Solicitando permissão de microfone ao usuário...")
                AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                    self?.logger.info("🔐 Resposta do usuário: \(granted ? "✅ Permitido" : "❌ Negado")")
                    continuation.resume(returning: granted)
                }
                
            case .denied:
                logger.warning("❌ Permissão de microfone negada pelo usuário")
                continuation.resume(returning: false)
                
            case .restricted:
                logger.warning("❌ Permissão de microfone restrita por política")
                continuation.resume(returning: false)
                
            @unknown default:
                logger.error("❌ Status de permissão desconhecido")
                continuation.resume(returning: false)
            }
        }
    }
    
    /// Solicitar permissão de áudio do sistema
    /// - Returns: True se a permissão foi concedida
    func requestSystemAudioPermission() async -> Bool {
        logger.info("🔐 Solicitando permissão de áudio do sistema...")
        
        // Verificar suporte do sistema
        guard isSystemAudioSupported() else {
            logger.warning("❌ Sistema não suporta captura de áudio do sistema")
            return false
        }
        
        if #available(macOS 13.0, *) {
            do {
                // Tentar obter conteúdo compartilhável para verificar permissões
                _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                logger.info("✅ Permissão de áudio do sistema concedida")
                return true
            } catch {
                logger.error("❌ Erro ao verificar permissão de áudio do sistema: \(error)")
                logger.error("💡 O usuário deve adicionar o app em: Configurações > Privacidade e Segurança > Gravação de Tela")
                return false
            }
        } else {
            logger.warning("❌ macOS < 13.0 não suporta ScreenCaptureKit")
            return false
        }
    }
    
    /// Verificar se todas as permissões necessárias foram concedidas
    /// - Parameter includeSystemAudio: Se deve verificar também permissão de áudio do sistema
    /// - Returns: True se todas as permissões estão concedidas
    func hasRequiredPermissions(includeSystemAudio: Bool = true) async -> Bool {
        logger.info("🔍 Verificando permissões necessárias...")
        
        // Verificar permissão de microfone
        let microphonePermission = await checkMicrophonePermission()
        guard microphonePermission else {
            logger.warning("❌ Permissão de microfone não concedida")
            return false
        }
        
        // Verificar permissão de áudio do sistema se necessário
        if includeSystemAudio && isSystemAudioSupported() {
            let systemAudioPermission = await checkSystemAudioPermission()
            guard systemAudioPermission else {
                logger.warning("❌ Permissão de áudio do sistema não concedida")
                return false
            }
        }
        
        logger.info("✅ Todas as permissões necessárias estão concedidas")
        return true
    }
    
    /// Obter status das permissões
    /// - Returns: Status detalhado das permissões
    func getPermissionStatus() async -> AudioPermissionStatus {
        logger.info("📋 Obtendo status das permissões...")
        
        let microphoneStatus = getMicrophonePermissionStatus()
        let systemAudioStatus = await getSystemAudioPermissionStatus()
        let systemSupported = isSystemAudioSupported()
        
        let status = AudioPermissionStatus(
            microphone: microphoneStatus,
            systemAudio: systemAudioStatus,
            isSystemAudioSupported: systemSupported,
            canRecord: microphoneStatus == .authorized,
            canRecordSystemAudio: systemSupported && systemAudioStatus == .authorized
        )
        
        logger.info("📋 Status: Mic=\(microphoneStatus.rawValue), System=\(systemAudioStatus.rawValue), Supported=\(systemSupported)")
        return status
    }
    
    /// Solicitar todas as permissões necessárias
    /// - Parameter includeSystemAudio: Se deve solicitar também permissão de áudio do sistema
    /// - Returns: Resultado da solicitação de permissões
    func requestAllPermissions(includeSystemAudio: Bool = true) async -> PermissionRequestResult {
        logger.info("🚀 Solicitando todas as permissões necessárias...")
        
        var results: [PermissionType: Bool] = [:]
        
        // Solicitar permissão de microfone
        let microphoneGranted = await requestMicrophonePermission()
        results[.microphone] = microphoneGranted
        
        // Solicitar permissão de áudio do sistema se necessário
        if includeSystemAudio && isSystemAudioSupported() {
            let systemAudioGranted = await requestSystemAudioPermission()
            results[.systemAudio] = systemAudioGranted
        }
        
        let allGranted = results.values.allSatisfy { $0 }
        
        let result = PermissionRequestResult(
            success: allGranted,
            microphoneGranted: results[.microphone] ?? false,
            systemAudioGranted: results[.systemAudio] ?? false,
            errors: generatePermissionErrors(from: results)
        )
        
        logger.info("🎯 Resultado: \(allGranted ? "✅ Sucesso" : "❌ Falhou")")
        return result
    }
    
    // MARK: - Private Methods
    
    private func checkMicrophonePermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        return status == .authorized
    }
    
    private func checkSystemAudioPermission() async -> Bool {
        guard isSystemAudioSupported() else { return false }
        
        if #available(macOS 13.0, *) {
            do {
                _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                return true
            } catch {
                return false
            }
        } else {
            return false
        }
    }
    
    private func getMicrophonePermissionStatus() -> PermissionAuthorizationStatus {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        
        switch status {
        case .authorized:
            return .authorized
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .denied
        }
    }
    
    private func getSystemAudioPermissionStatus() async -> PermissionAuthorizationStatus {
        guard isSystemAudioSupported() else { return .notSupported }
        
        let hasPermission = await checkSystemAudioPermission()
        return hasPermission ? .authorized : .denied
    }
    
    private func isSystemAudioSupported() -> Bool {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        return osVersion.majorVersion >= 13
    }
    
    private func generatePermissionErrors(from results: [PermissionType: Bool]) -> [PermissionError] {
        var errors: [PermissionError] = []
        
        for (type, granted) in results {
            if !granted {
                switch type {
                case .microphone:
                    errors.append(.microphoneDenied)
                case .systemAudio:
                    errors.append(.systemAudioDenied)
                }
            }
        }
        
        return errors
    }
    
    // MARK: - Guidance Methods
    
    /// Obter instruções para o usuário sobre como conceder permissões
    /// - Returns: Instruções detalhadas
    func getPermissionGuidance() -> PermissionGuidance {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        
        return PermissionGuidance(
            microphoneInstructions: """
            Para permitir acesso ao microfone:
            1. Abra Configurações do Sistema
            2. Vá para Privacidade e Segurança
            3. Clique em Microfone
            4. Ative a permissão para este app
            """,
            systemAudioInstructions: isSystemAudioSupported() ? """
            Para permitir captura de áudio do sistema:
            1. Abra Configurações do Sistema
            2. Vá para Privacidade e Segurança
            3. Clique em Gravação de Tela
            4. Ative a permissão para este app
            5. Reinicie o app se necessário
            """ : "Áudio do sistema não é suportado nesta versão do macOS (mínimo: 13.0)",
            troubleshooting: """
            Se ainda tiver problemas:
            1. Reinicie o app completamente
            2. Verifique se há atualizações do macOS
            3. Em casos extremos, redefina as permissões removendo e adicionando o app novamente
            """,
            macOSVersion: "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
        )
    }
}

// MARK: - Supporting Types

/// Status de autorização de permissão
enum PermissionAuthorizationStatus: String, CaseIterable {
    case authorized = "authorized"
    case denied = "denied"
    case notDetermined = "notDetermined"
    case restricted = "restricted"
    case notSupported = "notSupported"
    
    var description: String {
        switch self {
        case .authorized:
            return "✅ Autorizado"
        case .denied:
            return "❌ Negado"
        case .notDetermined:
            return "❓ Não determinado"
        case .restricted:
            return "🔒 Restrito"
        case .notSupported:
            return "🚫 Não suportado"
        }
    }
}

/// Tipos de permissão
enum PermissionType: String, CaseIterable {
    case microphone = "microphone"
    case systemAudio = "systemAudio"
}

/// Erros de permissão
enum PermissionError: Error, LocalizedError {
    case microphoneDenied
    case systemAudioDenied
    case systemNotSupported
    
    var errorDescription: String? {
        switch self {
        case .microphoneDenied:
            return "Permissão de microfone negada"
        case .systemAudioDenied:
            return "Permissão de áudio do sistema negada"
        case .systemNotSupported:
            return "Captura de áudio do sistema não suportada nesta versão do macOS"
        }
    }
}

/// Status completo das permissões
struct AudioPermissionStatus {
    let microphone: PermissionAuthorizationStatus
    let systemAudio: PermissionAuthorizationStatus
    let isSystemAudioSupported: Bool
    let canRecord: Bool
    let canRecordSystemAudio: Bool
    
    var description: String {
        return """
        Permissões de Áudio:
        • Microfone: \(microphone.description)
        • Áudio do Sistema: \(systemAudio.description)
        • Sistema Suportado: \(isSystemAudioSupported ? "✅" : "❌")
        • Pode Gravar: \(canRecord ? "✅" : "❌")
        • Pode Gravar Sistema: \(canRecordSystemAudio ? "✅" : "❌")
        """
    }
}

/// Resultado da solicitação de permissões
struct PermissionRequestResult {
    let success: Bool
    let microphoneGranted: Bool
    let systemAudioGranted: Bool
    let errors: [PermissionError]
    
    var description: String {
        return """
        Resultado da Solicitação:
        • Sucesso Geral: \(success ? "✅" : "❌")
        • Microfone: \(microphoneGranted ? "✅" : "❌")
        • Áudio do Sistema: \(systemAudioGranted ? "✅" : "❌")
        • Erros: \(errors.isEmpty ? "Nenhum" : errors.map { $0.localizedDescription }.joined(separator: ", "))
        """
    }
}

/// Orientações para o usuário
struct PermissionGuidance {
    let microphoneInstructions: String
    let systemAudioInstructions: String
    let troubleshooting: String
    let macOSVersion: String
} 