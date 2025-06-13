import Foundation
import AVFoundation
import Combine

/// Gerenciador centralizado de estados da gravacao
class RecordingState: ObservableObject {
    
    // MARK: - Published Properties (Interface publica)
    
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var currentDuration: TimeInterval = 0
    @Published var audioLevel: Float = 0.0
    @Published var errorMessage: String?
    @Published var availableInputDevices: [AudioDevice] = []
    @Published var selectedInputDevice: AudioDevice?
    @Published var systemAudioAvailable = false
    @Published var systemAudioEnabled = true
    
    // MARK: - Internal State Properties
    
    private(set) var currentConfiguration: AudioConfiguration?
    private(set) var currentMeetingId: UUID?
    private(set) var recordingStartTime: Date?
    private(set) var totalPausedDuration: TimeInterval = 0
    private(set) var pauseStartTime: Date?
    
    // MARK: - Synchronization State
    
    private(set) var firstMicBufferHostTime: UInt64?
    private(set) var firstSysBufferHostTime: UInt64?
    private(set) var isRecordingAfterWarmup: Bool = false
    
    // MARK: - Timer Management
    
    private var recordingTimer: Timer?
    
    // MARK: - Logger
    
    private let logger = LoggingService.shared
    
    // MARK: - Public Methods
    
    /// Preparar para nova gravacao
    func prepareForRecording(meetingId: UUID, configuration: AudioConfiguration) {
        logger.recordingEvent("Preparing recording state", meetingId: meetingId)
        
        currentMeetingId = meetingId
        currentConfiguration = configuration
        
        // Resetar estados
        isRecording = false
        isPaused = false
        currentDuration = 0
        audioLevel = 0.0
        errorMessage = nil
        totalPausedDuration = 0
        pauseStartTime = nil
        isRecordingAfterWarmup = false
        
        // Resetar sincronizacao
        firstMicBufferHostTime = nil
        firstSysBufferHostTime = nil
        
        logger.debug("Recording state prepared", category: .recording)
    }
    
    /// Iniciar gravacao real (apos warmup)
    func startRecording() {
        guard !isRecording else { return }
        
        logger.recordingEvent("Starting recording state", meetingId: currentMeetingId)
        
        isRecording = true
        isPaused = false
        recordingStartTime = Date()
        totalPausedDuration = 0
        currentDuration = 0
        errorMessage = nil
        isRecordingAfterWarmup = true
        
        startTimer()
        
        logger.recordingEvent("Recording state started", meetingId: currentMeetingId)
    }
    
    /// Pausar gravacao
    func pauseRecording() {
        guard isRecording && !isPaused else { return }
        
        logger.recordingEvent("Pausing recording state", meetingId: currentMeetingId)
        
        isPaused = true
        pauseStartTime = Date()
        stopTimer()
        
        logger.recordingEvent("Recording state paused", meetingId: currentMeetingId)
    }
    
    /// Retomar gravacao
    func resumeRecording() {
        guard isRecording && isPaused else { return }
        
        logger.recordingEvent("Resuming recording state", meetingId: currentMeetingId)
        
        if let pauseStart = pauseStartTime {
            totalPausedDuration += Date().timeIntervalSince(pauseStart)
        }
        
        isPaused = false
        pauseStartTime = nil
        startTimer()
        
        logger.recordingEvent("Recording state resumed", meetingId: currentMeetingId)
    }
    
    /// Parar gravacao
    func stopRecording() -> TimeInterval {
        guard isRecording else { return 0 }
        
        logger.recordingEvent("Stopping recording state", meetingId: currentMeetingId)
        
        let finalDuration = calculateFinalDuration()
        
        isRecording = false
        isPaused = false
        stopTimer()
        
        logger.recordingEvent("Recording state stopped", meetingId: currentMeetingId)
        logger.performance("Recording duration", duration: finalDuration)
        
        return finalDuration
    }
    
    /// Limpar estado
    func cleanup() {
        logger.debug("Cleaning up recording state", category: .recording)
        
        stopTimer()
        
        currentConfiguration = nil
        currentMeetingId = nil
        recordingStartTime = nil
        totalPausedDuration = 0
        pauseStartTime = nil
        isRecordingAfterWarmup = false
        
        // Resetar sincronizacao
        firstMicBufferHostTime = nil
        firstSysBufferHostTime = nil
        
        // Nao resetar @Published properties para manter UI state
    }
    
    // MARK: - Device Management
    
    /// Atualizar dispositivos disponiveis
    func updateAvailableDevices(_ devices: [AudioDevice]) {
        availableInputDevices = devices
        
        if selectedInputDevice == nil && !devices.isEmpty {
            selectedInputDevice = devices.first
        }
        
        logger.audioEvent("Available devices updated", details: [
            "count": devices.count
        ])
    }
    
    /// Selecionar dispositivo de entrada
    func selectInputDevice(_ device: AudioDevice) {
        selectedInputDevice = device
        
        logger.audioEvent("Input device selected", details: [
            "deviceName": device.name
        ])
    }
    
    /// Configurar disponibilidade do audio do sistema
    func setSystemAudioAvailable(_ available: Bool) {
        systemAudioAvailable = available
        
        logger.audioEvent("System audio availability updated", details: [
            "available": available
        ])
    }
    
    /// Configurar se o audio do sistema deve ser habilitado
    func setSystemAudioEnabled(_ enabled: Bool) {
        systemAudioEnabled = enabled
        
        logger.audioEvent("System audio setting changed", details: [
            "enabled": enabled,
            "available": systemAudioAvailable
        ])
    }
    
    // MARK: - Audio Level Management
    
    /// Atualizar nivel de audio para feedback visual
    func updateAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        let channelDataArray = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
        let rms = sqrt(channelDataArray.map { $0 * $0 }.reduce(0, +) / Float(channelDataArray.count))
        let avgPower = 20 * log10(max(rms, 1e-6))
        let normalizedPower = max(0, min(1, (avgPower + 80) / 80))
        
        // Atualizar na main thread
        DispatchQueue.main.async { [weak self] in
            self?.audioLevel = normalizedPower
        }
    }
    
    // MARK: - Synchronization Management
    
    /// Registrar primeiro buffer do microfone
    func registerFirstMicBuffer(hostTime: UInt64) {
        if firstMicBufferHostTime == nil {
            firstMicBufferHostTime = hostTime
            logger.debug("First microphone buffer registered", category: .recording)
        }
    }
    
    /// Registrar primeiro buffer do sistema
    func registerFirstSystemBuffer(hostTime: UInt64) {
        if firstSysBufferHostTime == nil {
            firstSysBufferHostTime = hostTime
            logger.debug("First system buffer registered", category: .recording)
        }
    }
    
    /// Verificar se sincronizacao pode ser inicializada
    func canInitializeSync() -> (micTime: UInt64, sysTime: UInt64)? {
        guard let micTime = firstMicBufferHostTime, 
              let sysTime = firstSysBufferHostTime else {
            return nil
        }
        return (micTime, sysTime)
    }
    
    // MARK: - Error Management
    
    /// Definir mensagem de erro
    func setError(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = message
        }
    }
    
    /// Limpar erro
    func clearError() {
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = nil
        }
    }
    
    // MARK: - Private Methods
    
    private func calculateFinalDuration() -> TimeInterval {
        guard let startTime = recordingStartTime else { return 0 }
        
        let totalElapsed = Date().timeIntervalSince(startTime)
        
        // Se ainda estiver pausado, adicionar tempo atual de pausa
        if isPaused, let pauseStart = pauseStartTime {
            let currentPauseDuration = Date().timeIntervalSince(pauseStart)
            totalPausedDuration += currentPauseDuration
        }
        
        let actualRecordingTime = totalElapsed - totalPausedDuration
        return max(0, actualRecordingTime)
    }
    
    private func startTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.recordingStartTime else { return }
            
            let totalElapsed = Date().timeIntervalSince(startTime)
            let actualRecordingTime = totalElapsed - self.totalPausedDuration
            
            if self.isPaused, let pauseStart = self.pauseStartTime {
                let currentPauseDuration = Date().timeIntervalSince(pauseStart)
                self.currentDuration = max(0, totalElapsed - self.totalPausedDuration - currentPauseDuration)
            } else {
                self.currentDuration = max(0, actualRecordingTime)
            }
        }
    }
    
    private func stopTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
}