import Foundation
@preconcurrency import AVFoundation

/// Serviço unificado de conversão de áudio - Substitui os 3 conversores duplicados
class UnifiedAudioConverter {
    
    // MARK: - Enums
    
    enum ConversionStrategy {
        case avFoundation    // Para conversões de arquivo padrão
        case ffmpeg         // Para conversões mais robustas/específicas
        case realtime       // Para processamento em tempo real
    }
    
    enum ConversionError: Error, LocalizedError {
        case inputFileNotFound(String)
        case outputPathGenerationFailed
        case conversionFailed(String)
        case strategyNotAvailable(ConversionStrategy)
        case configurationFailed
        
        var errorDescription: String? {
            switch self {
            case .inputFileNotFound(let path):
                return "Arquivo de entrada não encontrado: \(path)"
            case .outputPathGenerationFailed:
                return "Falha ao gerar caminho de saída"
            case .conversionFailed(let reason):
                return "Falha na conversão: \(reason)"
            case .strategyNotAvailable(let strategy):
                return "Estratégia não disponível: \(strategy)"
            case .configurationFailed:
                return "Falha na configuração do conversor"
            }
        }
    }
    
    // MARK: - Properties
    
    private let logger = LoggingService.shared
    private let fileManager = FileManager.default
    
    // Target format for transcription (16kHz mono PCM float32)
    private let transcriptionFormat: AVAudioFormat
    
    // Realtime converters for live audio processing
    private var systemAudioConverter: AVAudioConverter?
    private var microphoneConverter: AVAudioConverter?
    
    // MARK: - Initialization
    
    init() {
        self.transcriptionFormat = AVAudioFormat(
            standardFormatWithSampleRate: 16000.0,
            channels: 1
        )!
    }
    
    // MARK: - Public API
    
    /// Convert M4A to WAV for transcription
    /// - Parameters:
    ///   - inputPath: Path to input M4A file
    ///   - outputPath: Optional output path (will be generated if nil)
    ///   - strategy: Conversion strategy to use
    /// - Returns: Path to converted WAV file
    func convertM4AToWAV(
        inputPath: String,
        outputPath: String? = nil,
        strategy: ConversionStrategy = .avFoundation
    ) async throws -> String {
        
        logger.info("Starting M4A→WAV conversion", category: .audio)
        logger.debug("Input: \(inputPath), Strategy: \(strategy)", category: .audio)
        
        // Validate input
        guard fileManager.fileExists(atPath: inputPath) else {
            throw ConversionError.inputFileNotFound(inputPath)
        }
        
        // Generate output path if needed
        let finalOutputPath = try outputPath ?? generateWAVOutputPath(from: inputPath)
        
        // Execute conversion based on strategy
        switch strategy {
        case .avFoundation:
            return try await convertUsingAVFoundation(
                inputPath: inputPath, 
                outputPath: finalOutputPath
            )
        case .ffmpeg:
            return try await convertUsingFFmpeg(
                inputPath: inputPath, 
                outputPath: finalOutputPath
            )
        case .realtime:
            throw ConversionError.strategyNotAvailable(.realtime)
        }
    }
    
    /// Setup realtime converters for live audio processing
    /// - Parameters:
    ///   - systemFormat: System audio format (optional)
    ///   - microphoneFormat: Microphone audio format
    func setupRealtimeConverters(
        systemFormat: AVAudioFormat?,
        microphoneFormat: AVAudioFormat
    ) throws {
        
        logger.info("Setting up realtime audio converters", category: .audio)
        
        // Setup microphone converter
        guard let micConverter = AVAudioConverter(
            from: microphoneFormat, 
            to: transcriptionFormat
        ) else {
            logger.error("Failed to create microphone converter: \(microphoneFormat.sampleRate)Hz→\(transcriptionFormat.sampleRate)Hz", category: .audio)
            throw ConversionError.configurationFailed
        }
        micConverter.sampleRateConverterQuality = AVAudioQuality.high.rawValue
        self.microphoneConverter = micConverter
        
        let micSampleRateRatio = transcriptionFormat.sampleRate / microphoneFormat.sampleRate
        if abs(micSampleRateRatio - 1.0) > 0.1 {
            logger.warning("Large microphone sample rate conversion: \(microphoneFormat.sampleRate)Hz→\(transcriptionFormat.sampleRate)Hz (\(String(format: "%.2f", micSampleRateRatio))x)", category: .audio)
        }
        
        // Setup system audio converter if available
        if let systemFormat = systemFormat {
            guard let sysConverter = AVAudioConverter(
                from: systemFormat, 
                to: transcriptionFormat
            ) else {
                logger.error("Failed to create system audio converter", category: .audio)
                throw ConversionError.configurationFailed
            }
            sysConverter.sampleRateConverterQuality = AVAudioQuality.high.rawValue
            self.systemAudioConverter = sysConverter
            
            let sysSampleRateRatio = transcriptionFormat.sampleRate / systemFormat.sampleRate
            if abs(sysSampleRateRatio - 1.0) > 0.1 {
                logger.debug("System audio conversion ratio: \(String(format: "%.2f", sysSampleRateRatio))x", category: .audio)
            }
        }
        
        logger.info("Realtime converters configured successfully", category: .audio)
    }
    
    /// Convert realtime audio buffer
    /// - Parameters:
    ///   - inputBuffer: Input audio buffer
    ///   - isSystemAudio: Whether this is system audio or microphone
    /// - Returns: Converted audio buffer
    func convertRealtimeBuffer(
        _ inputBuffer: AVAudioPCMBuffer,
        isSystemAudio: Bool
    ) throws -> AVAudioPCMBuffer? {
        
        let converter = isSystemAudio ? systemAudioConverter : microphoneConverter
        let audioType = isSystemAudio ? "System" : "Microphone"
        
        guard let converter = converter else {
            logger.error("❌ \(audioType) converter not configured", category: .audio)
            throw ConversionError.configurationFailed
        }
        
        let inputFormat = converter.inputFormat
        let outputFormat = converter.outputFormat
        
        let sampleRateRatio = outputFormat.sampleRate / inputFormat.sampleRate
        let expectedOutputFrames = AVAudioFrameCount(Double(inputBuffer.frameLength) * sampleRateRatio)
        let bufferCapacity = max(expectedOutputFrames, 1024) // Mínimo de 1024 frames
        
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: transcriptionFormat,
            frameCapacity: bufferCapacity
        ) else {
            logger.error("Failed to create output buffer for \(audioType)", category: .audio)
            throw ConversionError.configurationFailed
        }
        
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return inputBuffer
        }
        
        let status = converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
        
        if status != .haveData {
            if let error = error {
                logger.error("\(audioType) conversion failed: \(error.localizedDescription)", category: .audio)
                throw ConversionError.conversionFailed(error.localizedDescription)
            } else {
                logger.warning("\(audioType) conversion status: \(status)", category: .audio)
            }
        }
        
        // Conversion completed successfully
        
        return outputBuffer
    }
    
    // MARK: - Private Implementation
    
    private func convertUsingAVFoundation(inputPath: String, outputPath: String) async throws -> String {
        logger.debug("Using AVFoundation conversion strategy", category: .audio)
        
        return try await withCheckedThrowingContinuation { continuation in
            let inputURL = URL(fileURLWithPath: inputPath)
            let outputURL = URL(fileURLWithPath: outputPath)
            
            // Create asset and reader
            let asset = AVAsset(url: inputURL)
            
            do {
                let reader = try AVAssetReader(asset: asset)
                let audioTrack = asset.tracks(withMediaType: .audio).first!
                
                // Configure reader output
                let readerOutput = AVAssetReaderAudioMixOutput(audioTracks: [audioTrack], audioSettings: nil)
                reader.add(readerOutput)
                
                // Create writer
                let writer = try AVAssetWriter(outputURL: outputURL, fileType: .wav)
                
                // Configure writer input
                let writerInput = AVAssetWriterInput(
                    mediaType: .audio,
                    outputSettings: [
                        AVFormatIDKey: kAudioFormatLinearPCM,
                        AVSampleRateKey: 16000,
                        AVNumberOfChannelsKey: 1,
                        AVLinearPCMBitDepthKey: 32,
                        AVLinearPCMIsFloatKey: true,
                        AVLinearPCMIsBigEndianKey: false,
                        AVLinearPCMIsNonInterleaved: false
                    ]
                )
                
                writer.add(writerInput)
                
                // Start conversion
                reader.startReading()
                writer.startWriting()
                writer.startSession(atSourceTime: CMTime.zero)
                
                writerInput.requestMediaDataWhenReady(on: DispatchQueue.global()) {
                    while writerInput.isReadyForMoreMediaData {
                        if let sampleBuffer = readerOutput.copyNextSampleBuffer() {
                            writerInput.append(sampleBuffer)
                        } else {
                            writerInput.markAsFinished()
                            writer.finishWriting {
                                if writer.status == .completed {
                                    self.logger.info("AVFoundation conversion completed", category: .audio)
                                    continuation.resume(returning: outputPath)
                                } else {
                                    let error = writer.error?.localizedDescription ?? "Unknown error"
                                    continuation.resume(throwing: ConversionError.conversionFailed(error))
                                }
                            }
                            break
                        }
                    }
                }
                
            } catch {
                continuation.resume(throwing: ConversionError.conversionFailed(error.localizedDescription))
            }
        }
    }
    
    private func convertUsingFFmpeg(inputPath: String, outputPath: String) async throws -> String {
        logger.debug("Using FFmpeg conversion strategy", category: .audio)
        
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")
            
            process.arguments = [
                "-nostdin",                // Don't wait for user input
                "-i", inputPath,           // Input file
                "-ar", "16000",            // Sample rate 16kHz
                "-ac", "1",                // Mono
                "-c:a", "pcm_f32le",       // PCM float32 little-endian
                "-y",                      // Overwrite existing file
                outputPath                 // Output file
            ]
            
            // Capture output
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            process.standardInput = nil
            
            process.terminationHandler = { process in
                if process.terminationStatus == 0 {
                    self.logger.info("FFmpeg conversion completed", category: .audio)
                    continuation.resume(returning: outputPath)
                } else {
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? "Unknown error"
                    continuation.resume(throwing: ConversionError.conversionFailed("FFmpeg failed: \(output)"))
                }
            }
            
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: ConversionError.conversionFailed(error.localizedDescription))
            }
        }
    }
    
    private func generateWAVOutputPath(from inputPath: String) throws -> String {
        let inputURL = URL(fileURLWithPath: inputPath)
        let directory = inputURL.deletingLastPathComponent()
        let baseName = inputURL.deletingPathExtension().lastPathComponent
        let outputURL = directory.appendingPathComponent("\(baseName)_converted.wav")
        
        logger.debug("Generated output path: \(outputURL.path)", category: .audio)
        return outputURL.path
    }
}

// MARK: - Protocol Conformance

extension UnifiedAudioConverter: AudioConverterProtocol {
    var targetFormat: AVAudioFormat {
        return transcriptionFormat
    }
    
    func setupConverters(
        systemFormat: AVAudioFormat?,
        microphoneFormat: AVAudioFormat
    ) throws {
        // Setup converters via protocol
        try setupRealtimeConverters(
            systemFormat: systemFormat,
            microphoneFormat: microphoneFormat
        )
    }
    
    func convertSystemAudio(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        return try? convertRealtimeBuffer(buffer, isSystemAudio: true)
    }
    
    func convertMicrophoneAudio(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let result = try? convertRealtimeBuffer(buffer, isSystemAudio: false) else {
            logger.error("Failed to convert microphone buffer", category: .audio)
            return nil
        }
        
        // Check for significant temporal distortion
        let inputDuration = Double(buffer.frameLength) / buffer.format.sampleRate
        let outputDuration = Double(result.frameLength) / result.format.sampleRate
        let ratio = outputDuration / inputDuration
        
        if abs(ratio - 1.0) > 0.15 { // Only warn for significant distortion (>15%)
            logger.warning("Temporal distortion in microphone conversion: \(String(format: "%.2f", ratio))x", category: .audio)
        }
        
        return result
    }
}