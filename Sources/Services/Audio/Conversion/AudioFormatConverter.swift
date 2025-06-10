import Foundation
import AVFoundation
import OSLog

/// Conversor responsável por padronizar formatos de áudio para 16kHz mono
class AudioFormatConverter: AudioConverterProtocol {
    private var systemAudioConverter: AVAudioConverter?
    private var microphoneConverter: AVAudioConverter?
    private let logger = Logger(subsystem: "AudioRecording", category: "FormatConverter")
    
    /// Formato de áudio de destino (16kHz mono)
    let targetFormat: AVAudioFormat
    
    init() {
        self.targetFormat = AVAudioFormat(
            standardFormatWithSampleRate: 16000.0,
            channels: 1
        )!
    }
    
    func setupConverters(systemFormat: AVAudioFormat?, microphoneFormat: AVAudioFormat) throws {
        // Converter para microfone (sempre necessário)
        guard let micConverter = AVAudioConverter(from: microphoneFormat, to: targetFormat) else {
            throw AudioFormatConverterError.configurationFailed
        }
        micConverter.sampleRateConverterQuality = AVAudioQuality.high.rawValue
        self.microphoneConverter = micConverter
        
        // Converter para áudio do sistema (se disponível)
        if let systemFormat = systemFormat {
            guard let sysConverter = AVAudioConverter(from: systemFormat, to: targetFormat) else {
                throw AudioFormatConverterError.configurationFailed
            }
            sysConverter.sampleRateConverterQuality = AVAudioQuality.high.rawValue
            self.systemAudioConverter = sysConverter
        }
        
        logger.info("Conversores configurados para 16kHz mono")
    }
    
    func convertSystemAudio(_ inputBuffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        return convert(inputBuffer, using: systemAudioConverter)
    }
    
    func convertMicrophoneAudio(_ inputBuffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        return convert(inputBuffer, using: microphoneConverter)
    }
    
    private func convert(_ inputBuffer: AVAudioPCMBuffer, using converter: AVAudioConverter?) -> AVAudioPCMBuffer? {
        guard let converter = converter else { return nil }
        
        let frameCapacity = AVAudioFrameCount(
            Double(inputBuffer.frameLength) * (targetFormat.sampleRate / inputBuffer.format.sampleRate)
        )
        
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: frameCapacity
        ) else { return nil }
        
        var error: NSError?
        let status = converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            outStatus.pointee = .haveData
            return inputBuffer
        }
        
        if status == .error {
            logger.error("Erro na conversão de formato: \(error?.localizedDescription ?? "desconhecido")")
            return nil
        }
        
        return outputBuffer
    }
} 