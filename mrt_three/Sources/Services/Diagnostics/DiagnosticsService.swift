import Foundation
import AVFoundation

/// Service especializado para diagnósticos de áudio e sistema
final class DiagnosticsService {
    private let logger = LoggingService.shared
    
    // MARK: - Buffer Tracking
    
    private var microphoneBuffersReceived = 0
    private var systemAudioBuffersReceived = 0
    private var microphoneFileWriteCount = 0
    private var systemAudioFileWriteCount = 0
    
    // MARK: - Public Methods
    
    func resetCounters() {
        microphoneBuffersReceived = 0
        systemAudioBuffersReceived = 0
        microphoneFileWriteCount = 0
        systemAudioFileWriteCount = 0
        
        logger.debug("Diagnostic counters reset", category: .diagnostics)
    }
    
    func trackMicrophoneBuffer(_ buffer: AVAudioPCMBuffer) {
        microphoneBuffersReceived += 1
        
        if microphoneBuffersReceived == 1 {
            logger.audioEvent("First microphone buffer received", details: [
                "sampleRate": buffer.format.sampleRate,
                "channels": buffer.format.channelCount,
                "frames": buffer.frameLength
            ])
        }
    }
    
    func trackSystemAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        systemAudioBuffersReceived += 1
        
        if systemAudioBuffersReceived == 1 {
            logger.audioEvent("First system audio buffer received", details: [
                "sampleRate": buffer.format.sampleRate,
                "channels": buffer.format.channelCount,
                "frames": buffer.frameLength
            ])
        }
    }
    
    func trackMicrophoneFileWrite() {
        microphoneFileWriteCount += 1
        
        if microphoneFileWriteCount % 100 == 0 {
            logger.fileOperation("Microphone file writes: \(microphoneFileWriteCount)")
        }
    }
    
    func trackSystemAudioFileWrite() {
        systemAudioFileWriteCount += 1
        
        if systemAudioFileWriteCount % 50 == 0 {
            logger.fileOperation("System audio file writes: \(systemAudioFileWriteCount)")
        }
    }
    
    func getSystemAudioFileWriteCount() -> Int {
        return systemAudioFileWriteCount
    }
    
    func getMicrophoneFileWriteCount() -> Int {
        return microphoneFileWriteCount
    }
    
    // MARK: - Diagnostic Checks
    
    func performBufferCheck(after delay: TimeInterval = 5.0) {
        Task {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await logBufferDiagnostics()
        }
    }
    
    @MainActor
    private func logBufferDiagnostics() {
        logger.info("Buffer diagnostics check", category: .diagnostics)
        
        // Microphone diagnostics
        if microphoneBuffersReceived == 0 {
            logger.warning("No microphone buffers received", category: .diagnostics)
            logMicrophoneTroubleshooting()
        } else {
            logger.info("Microphone buffers: \(microphoneBuffersReceived)", category: .diagnostics)
        }
        
        // System audio diagnostics
        if systemAudioBuffersReceived == 0 {
            logger.warning("No system audio buffers received", category: .diagnostics)
            logSystemAudioTroubleshooting()
        } else {
            logger.info("System audio buffers: \(systemAudioBuffersReceived)", category: .diagnostics)
        }
    }
    
    func logFinalDiagnostics() {
        logger.info("Final recording diagnostics", category: .diagnostics)
        logger.info("Total microphone buffers: \(microphoneBuffersReceived)", category: .diagnostics)
        logger.info("Total system audio buffers: \(systemAudioBuffersReceived)", category: .diagnostics)
        logger.info("Microphone file writes: \(microphoneFileWriteCount)", category: .diagnostics)
        logger.info("System audio file writes: \(systemAudioFileWriteCount)", category: .diagnostics)
    }
    
    // MARK: - System Diagnostics
    
    func logSystemCapabilities() {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        let macOSVersion = "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
        
        logger.info("System diagnostics", category: .diagnostics)
        logger.info("macOS Version: \(macOSVersion)", category: .diagnostics)
        logger.info("ScreenCaptureKit available: \(isScreenCaptureKitAvailable())", category: .diagnostics)
    }
    
    func logAudioConfiguration(_ configuration: AudioConfiguration) {
        logger.info("Audio configuration", category: .diagnostics)
        logger.audioEvent("Configuration details", details: [
            "strategy": configuration.captureStrategy.rawValue,
            "sampleRate": configuration.sampleRate,
            "channels": configuration.channels,
            "bufferSize": configuration.bufferSize,
            "systemAudioEnabled": configuration.systemAudioConfig != nil
        ])
    }
    
    func validateAudioFormats(fileFormat: AVAudioFormat, bufferFormat: AVAudioFormat) -> Bool {
        let isCompatible = fileFormat.sampleRate == bufferFormat.sampleRate &&
                          fileFormat.channelCount == bufferFormat.channelCount
        
        if !isCompatible {
            logger.warning("Audio format mismatch detected", category: .diagnostics)
            logger.audioEvent("Format details", details: [
                "file_sampleRate": fileFormat.sampleRate,
                "file_channels": fileFormat.channelCount,
                "buffer_sampleRate": bufferFormat.sampleRate,
                "buffer_channels": bufferFormat.channelCount
            ])
        }
        
        return isCompatible
    }
    
    // MARK: - Private Helpers
    
    private func logMicrophoneTroubleshooting() {
        logger.info("Microphone troubleshooting suggestions:", category: .diagnostics)
        logger.info("• Check if microphone is connected and working", category: .diagnostics)
        logger.info("• Verify microphone volume is not muted", category: .diagnostics)
        logger.info("• Check if other applications are using the microphone", category: .diagnostics)
        logger.info("• Verify microphone permissions are granted", category: .diagnostics)
    }
    
    private func logSystemAudioTroubleshooting() {
        logger.info("System audio troubleshooting suggestions:", category: .diagnostics)
        logger.info("• Check if any audio is playing on the system", category: .diagnostics)
        logger.info("• Verify ScreenCaptureKit permissions are granted", category: .diagnostics)
        logger.info("• Check ScreenCaptureKit configuration", category: .diagnostics)
        logger.info("• Ensure app is not excluded in excludesCurrentProcessAudio", category: .diagnostics)
    }
    
    private func isScreenCaptureKitAvailable() -> Bool {
        if #available(macOS 12.3, *) {
            return true
        } else {
            return false
        }
    }
    
    // MARK: - Performance Monitoring
    
    func monitorPerformance<T>(operation: String, category: LogCategory = .performance, _ block: () throws -> T) rethrows -> T {
        let timer = logger.startOperation(operation, category: category)
        do {
            let result = try block()
            timer.finish(success: true)
            return result
        } catch {
            timer.finish(success: false)
            throw error
        }
    }
    
    func monitorAsyncPerformance<T>(operation: String, category: LogCategory = .performance, _ block: () async throws -> T) async rethrows -> T {
        let timer = logger.startOperation(operation, category: category)
        do {
            let result = try await block()
            timer.finish(success: true)
            return result
        } catch {
            timer.finish(success: false)
            throw error
        }
    }
}