import Foundation
import CoreAudio
import AVFoundation
import AudioToolbox

/// Serviço de captura de áudio usando Core Audio Tap via Helper Tool privilegiada
/// Substitui a implementação experimental por arquitetura XPC funcional
@available(macOS 13, *)
class CoreAudioTapService: NSObject, SystemAudioCaptureProtocol {
    
    // MARK: - SystemAudioCaptureProtocol Properties
    
    var onAudioReceived: ((AVAudioPCMBuffer, UInt64) -> Void)?
    
    private var _isCapturing = false
    private var _isPaused = false
    
    var isCapturing: Bool { _isCapturing }
    var isPaused: Bool { _isPaused }
    
    var isSystemAudioSupported: Bool {
        return CoreAudioTapService.isSupported()
    }
    
    // MARK: - Private Properties
    
    private let logger = LoggingService.shared
    private let xpcService: CoreAudioTapXPCService
    private var currentConfiguration: AudioConfiguration?
    
    // MARK: - Initialization
    
    override init() {
        self.xpcService = CoreAudioTapXPCService.createService()
        super.init()
        
        // Configurar callback do XPC service
        xpcService.onAudioReceived = { [weak self] buffer, hostTime in
            self?.handleAudioBuffer(buffer, hostTime: hostTime)
        }
        
        logger.info("🎯 CoreAudioTapService (XPC) inicializado", category: .audio)
    }
    
    deinit {
        logger.info("CoreAudioTapService deinitializando", category: .audio)
        
        // Parar captura de forma síncrona para evitar warnings
        if isCapturing {
            Task { [weak self] in
                await self?.stopCapture()
            }
        }
    }
    
    // MARK: - SystemAudioCaptureProtocol Implementation
    
    func startCapture(configuration: AudioConfiguration) async throws {
        logger.info("🎬 Iniciando Core Audio Tap (XPC + Helper Tool)", category: .audio)
        
        guard !isCapturing else {
            logger.warning("CoreAudioTap XPC já está ativo", category: .audio)
            return
        }
        
        // Verificar suporte do sistema
        guard isSystemAudioSupported else {
            throw CoreAudioTapError.incompatibleVersion
        }
        
        // Armazenar configuração
        currentConfiguration = configuration
        
        do {
            // Delegar para XPC service
            try await xpcService.startCapture(configuration: configuration)
            
            _isCapturing = true
            _isPaused = false
            
            logger.info("✅ Core Audio Tap (XPC) iniciado com sucesso", category: .audio)
            
        } catch {
            logger.error("❌ Falha ao iniciar Core Audio Tap XPC", error: error, category: .audio)
            await cleanup()
            throw mapXPCError(error)
        }
    }
    
    func stopCapture() async {
        logger.info("🛑 Parando Core Audio Tap (XPC)", category: .audio)
        
        _isCapturing = false
        _isPaused = false
        
        await xpcService.stopCapture()
        await cleanup()
        
        logger.info("✅ Core Audio Tap (XPC) parado", category: .audio)
    }
    
    func pauseCapture() async {
        guard isCapturing && !isPaused else { return }
        
        logger.info("⏸️ Pausando Core Audio Tap (XPC)", category: .audio)
        _isPaused = true
        
        await xpcService.pauseCapture()
    }
    
    func resumeCapture() async {
        guard isCapturing && isPaused else { return }
        
        logger.info("▶️ Retomando Core Audio Tap (XPC)", category: .audio)
        _isPaused = false
        
        await xpcService.resumeCapture()
    }
    
    func requestSystemPermissions() async -> Bool {
        logger.info("🔐 Solicitando permissões para Core Audio Tap XPC", category: .audio)
        
        let permissionsGranted = await xpcService.requestSystemPermissions()
        
        if permissionsGranted {
            logger.info("✅ Permissões Core Audio Tap XPC concedidas", category: .audio)
        } else {
            logger.warning("❌ Permissões Core Audio Tap XPC negadas", category: .audio)
        }
        
        return permissionsGranted
    }
    
    func getSystemAudioCapabilities() -> SystemAudioCapabilities {
        let capabilities = xpcService.getSystemAudioCapabilities()
        
        logger.debug("Core Audio Tap XPC capabilities: \(capabilities.isSupported)", category: .audio)
        
        return capabilities
    }
    
    func isSystemAudioAvailable() async -> Bool {
        let available = await xpcService.isSystemAudioAvailable()
        
        logger.debug("Core Audio Tap XPC disponível: \(available)", category: .audio)
        
        return available
    }
    
    // MARK: - Private Implementation
    
    private func handleAudioBuffer(_ buffer: AVAudioPCMBuffer, hostTime: UInt64) {
        // Repassar buffer para o callback registrado
        onAudioReceived?(buffer, hostTime)
    }
    
    private func cleanup() async {
        logger.debug("Limpando recursos Core Audio Tap XPC", category: .audio)
        
        currentConfiguration = nil
        
        logger.debug("Cleanup Core Audio Tap XPC concluído", category: .audio)
    }
    
    private func mapXPCError(_ error: Error) -> CoreAudioTapError {
        if let xpcError = error as? XPCError {
            switch xpcError {
            case .connectionFailed:
                return .tapInstallationFailed
            case .helperNotInstalled:
                return .tapInstallationFailed
            case .installationFailed:
                return .tapInstallationFailed
            case .communicationTimeout:
                return .engineStartFailed(error)
            case .invalidResponse:
                return .engineStartFailed(error)
            case .helperVersionMismatch:
                return .incompatibleVersion
            }
        }
        
        if let systemError = error as? SystemAudioCaptureError {
            switch systemError {
            case .systemVersionNotSupported:
                return .incompatibleVersion
            case .permissionDenied:
                return .tapInstallationFailed
            case .configurationFailed:
                return .unsupportedConfiguration
            case .noAudioDeviceFound:
                return .tapInstallationFailed
            case .captureSessionFailed:
                return .engineStartFailed(error)
            case .noDisplayFound:
                return .tapInstallationFailed
            case .captureStartFailed(let underlyingError):
                return .engineStartFailed(underlyingError)
            case .internalError:
                return .engineStartFailed(error)
            }
        }
        
        return .engineStartFailed(error)
    }
}

// MARK: - Core Audio Tap Errors (Mantidos para compatibilidade)

enum CoreAudioTapError: LocalizedError {
    case incompatibleVersion
    case engineCreationFailed
    case engineNotInitialized
    case engineStartFailed(Error)
    case tapInstallationFailed
    case unsupportedConfiguration
    
    var errorDescription: String? {
        switch self {
        case .incompatibleVersion:
            return "Core Audio Tap requer macOS 13 ou superior com Helper Tool"
        case .engineCreationFailed:
            return "Falha ao criar engine de áudio"
        case .engineNotInitialized:
            return "Engine de áudio não inicializado"
        case .engineStartFailed(let error):
            return "Falha ao iniciar engine: \(error.localizedDescription)"
        case .tapInstallationFailed:
            return "Falha ao instalar ou conectar Helper Tool"
        case .unsupportedConfiguration:
            return "Configuração não suportada para Core Audio Tap XPC"
        }
    }
}

// MARK: - Version Compatibility Extension

@available(macOS 13, *)
extension CoreAudioTapService {
    
    /// Verifica se o sistema atual suporta Core Audio Tap via XPC
    static func isSupported() -> Bool {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        
        // Requer macOS 13+ para arquitetura XPC + Helper Tool
        if osVersion.majorVersion >= 13 {
            return true
        }
        
        return false
    }
    
    /// Descrição das capacidades do Core Audio Tap XPC
    static func getCapabilityDescription() -> String {
        if isSupported() {
            return "Core Audio Tap via XPC + Helper Tool (macOS 13+)"
        } else {
            let osVersion = ProcessInfo.processInfo.operatingSystemVersion
            return "Core Audio Tap XPC não suportado (Atual: macOS \(osVersion.majorVersion).\(osVersion.minorVersion), Requerido: 13+)"
        }
    }
    
    /// Verificar status da Helper Tool
    static func getHelperToolStatus() async -> HelperInstallationStatus {
        let manager = HelperInstallationManager.shared
        return await manager.getInstallationStatus()
    }
}