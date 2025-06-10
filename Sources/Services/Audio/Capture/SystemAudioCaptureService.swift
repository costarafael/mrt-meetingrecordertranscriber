import Foundation
import AVFoundation
import ScreenCaptureKit
import OSLog

/// Service especializado para captura de áudio do sistema
class SystemAudioCaptureService: SystemAudioCaptureProtocol {
    
    // MARK: - AudioCaptureProtocol Properties
    
    var onAudioReceived: ((AVAudioPCMBuffer, UInt64) -> Void)?
    
    private var _isCapturing = false
    private var _isPaused = false
    
    var isCapturing: Bool { _isCapturing }
    var isPaused: Bool { _isPaused }
    
    // MARK: - SystemAudioCaptureProtocol Properties
    
    var isSystemAudioSupported: Bool {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        return osVersion.majorVersion >= 13
    }
    
    // MARK: - Private Properties
    
    private var screenCaptureKitPipeline: ScreenCaptureKitAudioPipeline?
    private var formatConverter: AudioConverterProtocol?
    private var currentConfiguration: AudioConfiguration?
    private let logger = Logger(subsystem: "AudioRecording", category: "SystemAudioCapture")
    
    // MARK: - Initialization
    
    init() {
        logger.info("🔊 SystemAudioCaptureService inicializado")
    }
    
    // MARK: - AudioCaptureProtocol Methods
    
    func startCapture(configuration: AudioConfiguration) async throws {
        logger.info("🔊 Iniciando captura de áudio do sistema...")
        
        // Verificar suporte do sistema
        guard isSystemAudioSupported else {
            throw SystemAudioCaptureError.systemVersionNotSupported
        }
        
        // Verificar permissões
        guard await requestSystemPermissions() else {
            throw SystemAudioCaptureError.permissionDenied
        }
        
        // Configurar pipeline
        try await setupSystemAudioPipeline(configuration: configuration)
        
        // Iniciar captura
        try await screenCaptureKitPipeline?.startCapture(configuration: configuration)
        
        _isCapturing = true
        _isPaused = false
        currentConfiguration = configuration
        
        logger.info("✅ Captura de áudio do sistema iniciada com sucesso")
    }
    
    func stopCapture() async {
        logger.info("🛑 Parando captura de áudio do sistema...")
        
        _isCapturing = false
        _isPaused = false
        
        await screenCaptureKitPipeline?.stopCapture()
        screenCaptureKitPipeline = nil
        formatConverter = nil
        currentConfiguration = nil
        
        logger.info("✅ Captura de áudio do sistema parada")
    }
    
    func pauseCapture() async {
        guard _isCapturing && !_isPaused else { return }
        
        _isPaused = true
        await screenCaptureKitPipeline?.pauseCapture()
        
        logger.info("⏸️ Captura de áudio do sistema pausada")
    }
    
    func resumeCapture() async {
        guard _isCapturing && _isPaused else { return }
        
        _isPaused = false
        await screenCaptureKitPipeline?.resumeCapture()
        
        logger.info("▶️ Captura de áudio do sistema retomada")
    }
    
    // MARK: - SystemAudioCaptureProtocol Methods
    
    func requestSystemPermissions() async -> Bool {
        guard isSystemAudioSupported else {
            logger.warning("❌ Sistema não suporta captura de áudio do sistema")
            return false
        }
        
        if #available(macOS 13.0, *) {
            do {
                // Tentar obter conteúdo compartilhável para verificar permissões
                _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                logger.info("✅ Permissões de ScreenCaptureKit concedidas")
                return true
            } catch {
                logger.error("❌ Erro de permissão ScreenCaptureKit: \(error)")
                return false
            }
        } else {
            return false
        }
    }
    
    func isSystemAudioAvailable() async -> Bool {
        // Verificar suporte do sistema operacional
        guard isSystemAudioSupported else {
            logger.warning("❌ Sistema não suporta captura de áudio do sistema")
            return false
        }
        
        // Verificar permissões
        let hasPermissions = await requestSystemPermissions()
        if !hasPermissions {
            logger.warning("❌ Permissões para captura de áudio do sistema não concedidas")
            return false
        }
        
        // Em sistemas suportados com permissões, verificar disponibilidade
        if #available(macOS 13.0, *) {
            do {
                // Verificar se há algum conteúdo de áudio disponível
                _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
                
                // Se ScreenCaptureKit está disponível e permitido, presumimos que o áudio do sistema
                // também está disponível até prova em contrário (durante a captura)
                let hasAudioSources = true
                
                logger.info("🔊 Áudio do sistema presumido disponível: \(hasAudioSources ? "✅" : "❌")")
                return hasAudioSources
            } catch {
                logger.error("❌ Erro ao verificar disponibilidade de áudio: \(error)")
                return false
            }
        } else {
            return false
        }
    }
    
    // MARK: - Private Methods
    
    @available(macOS 13.0, *)
    private func setupSystemAudioPipeline(configuration: AudioConfiguration) async throws {
        logger.info("🔧 Configurando pipeline de áudio do sistema...")
        
        // Criar pipeline ScreenCaptureKit
        screenCaptureKitPipeline = ScreenCaptureKitAudioPipeline()
        
        // Configurar callback para processar áudio
        screenCaptureKitPipeline?.onAudioReceived = { [weak self] buffer, hostTime in
            self?.processSystemAudioBuffer(buffer, hostTime: hostTime)
        }
        
        // Configurar conversor de formato
        formatConverter = AudioFormatConverter()
        
        // Nota: O formato do sistema será conhecido após a primeira captura
        // A configuração do conversor será feita no processamento do primeiro buffer
        
        logger.info("🔧 Pipeline de áudio do sistema configurado")
    }
    
    private func processSystemAudioBuffer(_ buffer: AVAudioPCMBuffer, hostTime: UInt64) {
        guard _isCapturing && !_isPaused else { return }
        
        // Configurar conversor na primeira execução se ainda não foi configurado
        if formatConverter?.targetFormat == nil {
            setupFormatConverterIfNeeded(inputFormat: buffer.format)
        }
        
        // Converter formato se necessário
        let processedBuffer = formatConverter?.convertSystemAudio(buffer) ?? buffer
        
        // Chamar callback
        onAudioReceived?(processedBuffer, hostTime)
    }
    
    private func setupFormatConverterIfNeeded(inputFormat: AVAudioFormat) {
        do {
            try formatConverter?.setupConverters(systemFormat: inputFormat, microphoneFormat: inputFormat)
            logger.info("🔄 Conversor de formato configurado para sistema: \(inputFormat.sampleRate)Hz")
        } catch {
            logger.error("❌ Erro ao configurar conversor: \(error)")
        }
    }
    
    // MARK: - Strategy Detection
    
    private func detectBestCaptureStrategy() -> AudioCaptureStrategy {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        
        if osVersion.majorVersion >= 14 && osVersion.minorVersion >= 2 {
            return .coreAudioTaps
        } else if osVersion.majorVersion >= 13 {
            return .screenCaptureKit
        } else {
            return .microphoneOnly
        }
    }
    
    // MARK: - Capability Checking
    
    func getSystemAudioCapabilities() -> SystemAudioCapabilities {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        
        return SystemAudioCapabilities(
            isSupported: isSystemAudioSupported,
            supportedStrategy: detectBestCaptureStrategy(),
            macOSVersion: "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)",
            recommendedConfiguration: isSystemAudioSupported ? .mixed : .microphoneOnly
        )
    }
}

// MARK: - Supporting Types

/// Capacidades de captura de áudio do sistema
struct SystemAudioCapabilities {
    let isSupported: Bool
    let supportedStrategy: AudioCaptureStrategy
    let macOSVersion: String
    let recommendedConfiguration: AudioConfiguration
    
    var description: String {
        return """
        Sistema de Áudio:
        - Suportado: \(isSupported ? "✅" : "❌")
        - Estratégia: \(supportedStrategy)
        - macOS: \(macOSVersion)
        - Configuração recomendada: \(recommendedConfiguration.captureStrategy)
        """
    }
} 