import Foundation
import AVFoundation

/// Protocolo para conversão de formato de áudio
protocol AudioConverterProtocol {
    /// Formato de áudio de destino
    var targetFormat: AVAudioFormat { get }
    
    /// Configurar conversores com formatos de entrada
    /// - Parameters:
    ///   - systemFormat: Formato do áudio do sistema (opcional)
    ///   - microphoneFormat: Formato do áudio do microfone
    func setupConverters(systemFormat: AVAudioFormat?, microphoneFormat: AVAudioFormat) throws
    
    /// Converter buffer de áudio do sistema
    /// - Parameter inputBuffer: Buffer de entrada
    /// - Returns: Buffer convertido ou nil se falhar
    func convertSystemAudio(_ inputBuffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer?
    
    /// Converter buffer de áudio do microfone
    /// - Parameter inputBuffer: Buffer de entrada
    /// - Returns: Buffer convertido ou nil se falhar
    func convertMicrophoneAudio(_ inputBuffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer?
}

// MARK: - Erros

/// Erros relacionados à conversão de formato de áudio
enum AudioFormatConverterError: Error, LocalizedError {
    case configurationFailed
    case conversionFailed
    case invalidFormat
    
    var errorDescription: String? {
        switch self {
        case .configurationFailed:
            return "Falha na configuração do conversor de áudio"
        case .conversionFailed:
            return "Falha na conversão do formato de áudio"
        case .invalidFormat:
            return "Formato de áudio inválido"
        }
    }
} 