import Foundation
import AVFoundation

/// Protocolo base para services de captura de áudio
protocol AudioCaptureProtocol {
    /// Callback para receber buffers de áudio capturados
    var onAudioReceived: ((AVAudioPCMBuffer, UInt64) -> Void)? { get set }
    
    /// Iniciar captura de áudio
    /// - Parameter configuration: Configuração de captura
    func startCapture(configuration: AudioConfiguration) async throws
    
    /// Parar captura de áudio
    func stopCapture() async
    
    /// Pausar captura de áudio
    func pauseCapture() async
    
    /// Retomar captura de áudio
    func resumeCapture() async
    
    /// Verificar se está capturando
    var isCapturing: Bool { get }
    
    /// Verificar se captura está pausada
    var isPaused: Bool { get }
}

/// Protocolo específico para captura de áudio do sistema
protocol SystemAudioCaptureProtocol: AudioCaptureProtocol {
    /// Verificar se o sistema suporta captura de áudio do sistema
    var isSystemAudioSupported: Bool { get }
    
    /// Solicitar permissões necessárias para captura do sistema
    func requestSystemPermissions() async -> Bool
    
    /// Obter capacidades de áudio do sistema
    func getSystemAudioCapabilities() -> SystemAudioCapabilities
    
    /// Verificar se o áudio do sistema está disponível
    func isSystemAudioAvailable() async -> Bool
}

/// Protocolo especializado para captura de áudio do microfone
protocol MicrophoneCaptureProtocol: AudioCaptureProtocol {
    
    // MARK: - Device Management
    
    var availableInputDevices: [AudioDevice] { get }
    var selectedInputDevice: AudioDevice? { get }
    
    func loadAvailableDevices()
    func requestMicrophonePermissions() async -> Bool
    func selectInputDevice(_ device: AudioDevice)
} 