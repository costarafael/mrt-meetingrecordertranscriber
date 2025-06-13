import Foundation
import AVFoundation
import Combine

/// Protocolo para callbacks do WarmupManager
protocol WarmupManagerDelegate: AnyObject {
    func warmupDidComplete()
    func warmupProgressDidUpdate(progress: Double, countdown: Int)
}

/// Gerenciador especializado para periodo de aquecimento e analise de estabilidade
class WarmupManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isWarmingUp: Bool = false
    @Published var warmupProgress: Double = 0.0
    @Published var warmupCountdown: Int = 3
    
    // MARK: - Configuration
    
    private let warmupDurationSeconds: TimeInterval = 3.0
    private let maxStabilityAnalysisTime: TimeInterval = 5.0
    private let requiredStableBuffers: Int = 3
    private let maxStabilityAttempts: Int = 3
    
    // MARK: - State Properties
    
    private var isInWarmupPeriod: Bool = false
    private var warmupStartTime: Date?
    private var warmupTimer: Timer?
    private var captureStartedDuringWarmup: Bool = false
    
    // MARK: - Stability Analysis Properties
    
    private var isExtendedWarmupActive: Bool = false
    private var stabilityAnalysisActive: Bool = false
    private var stabilityAnalysisStartTime: Date?
    private var stabilityAttempts: Int = 0
    private var consecutiveStableBuffers: Int = 0
    
    // MARK: - Buffer Analysis
    
    private var lastMicBufferTime: Double = 0
    private var lastSysBufferTime: Double = 0
    private var micBufferIntervals: [Double] = []
    private var sysBufferIntervals: [Double] = []
    
    // MARK: - Dependencies
    
    weak var delegate: WarmupManagerDelegate?
    private let logger = LoggingService.shared
    
    // MARK: - Public Methods
    
    /// Iniciar periodo de aquecimento
    func startWarmup() {
        logger.recordingEvent("Starting warmup period")
        
        // Reset all state
        resetState()
        
        // Set initial state
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.isWarmingUp = true
            self.warmupProgress = 0.0
            self.warmupCountdown = Int(self.warmupDurationSeconds)
            self.isInWarmupPeriod = true
            self.warmupStartTime = Date()
            self.captureStartedDuringWarmup = false
        }
        
        // Start countdown timer
        startWarmupTimer()
    }
    
    /// Cancelar periodo de aquecimento
    func cancelWarmup() {
        logger.recordingEvent("Cancelling warmup period")
        
        // Stop timer
        warmupTimer?.invalidate()
        warmupTimer = nil
        
        // Reset state
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.isWarmingUp = false
            self.isInWarmupPeriod = false
            self.stabilityAnalysisActive = false
            self.isExtendedWarmupActive = false
        }
        
        resetState()
    }
    
    /// Marcar que a captura foi iniciada durante o warmup
    func markCaptureStarted() {
        captureStartedDuringWarmup = true
        logger.recordingEvent("Audio capture started during warmup")
    }
    
    /// Verificar se esta no periodo de warmup
    var isInWarmup: Bool {
        return isInWarmupPeriod
    }
    
    /// Verificar se captura foi iniciada durante warmup
    var wasCaptureStartedDuringWarmup: Bool {
        return captureStartedDuringWarmup
    }
    
    // MARK: - Buffer Analysis
    
    /// Analisar buffer do microfone para estabilidade
    func analyzeMicrophoneBuffer(_ buffer: AVAudioPCMBuffer) {
        guard stabilityAnalysisActive else { return }
        
        let currentTime = CACurrentMediaTime()
        
        // Calcular intervalo entre buffers
        if lastMicBufferTime > 0 {
            let interval = currentTime - lastMicBufferTime
            micBufferIntervals.append(interval)
            
            // Manter apenas os ultimos 10 intervalos para analise
            if micBufferIntervals.count > 10 {
                micBufferIntervals.removeFirst()
            }
            
            // Verificar estabilidade nos intervalos
            if micBufferIntervals.count >= 3 {
                let isStable = checkBufferIntervalStability(micBufferIntervals)
                updateStabilityCount(microphoneStable: isStable)
            }
        }
        
        lastMicBufferTime = currentTime
    }
    
    /// Analisar buffer do sistema para estabilidade
    func analyzeSystemBuffer(_ buffer: AVAudioPCMBuffer) {
        guard stabilityAnalysisActive else { return }
        
        let currentTime = CACurrentMediaTime()
        
        // Calcular intervalo entre buffers
        if lastSysBufferTime > 0 {
            let interval = currentTime - lastSysBufferTime
            sysBufferIntervals.append(interval)
            
            // Manter apenas os ultimos 10 intervalos para analise
            if sysBufferIntervals.count > 10 {
                sysBufferIntervals.removeFirst()
            }
            
            // Verificar estabilidade nos intervalos
            if sysBufferIntervals.count >= 3 && micBufferIntervals.count >= 3 {
                let isSysStable = checkBufferIntervalStability(sysBufferIntervals)
                let isMicStable = checkBufferIntervalStability(micBufferIntervals)
                
                updateStabilityCount(microphoneStable: isMicStable, systemStable: isSysStable)
            }
        }
        
        lastSysBufferTime = currentTime
    }
    
    // MARK: - Private Methods
    
    private func resetState() {
        isInWarmupPeriod = false
        warmupStartTime = nil
        captureStartedDuringWarmup = false
        isExtendedWarmupActive = false
        stabilityAnalysisActive = false
        stabilityAnalysisStartTime = nil
        stabilityAttempts = 0
        consecutiveStableBuffers = 0
        
        // Reset buffer analysis
        lastMicBufferTime = 0
        lastSysBufferTime = 0
        micBufferIntervals.removeAll()
        sysBufferIntervals.removeAll()
    }
    
    private func startWarmupTimer() {
        // Stop existing timer
        warmupTimer?.invalidate()
        
        // Create new timer on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.warmupTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
                guard let self = self,
                      let startTime = self.warmupStartTime else {
                    timer.invalidate()
                    return
                }
                
                let elapsed = Date().timeIntervalSince(startTime)
                let progress = min(1.0, elapsed / self.warmupDurationSeconds)
                let remaining = max(0, Int(ceil(self.warmupDurationSeconds - elapsed)))
                
                // Update UI
                self.warmupProgress = progress
                if self.warmupCountdown != remaining {
                    self.warmupCountdown = remaining
                }
                
                // Notify delegate of progress
                self.delegate?.warmupProgressDidUpdate(progress: progress, countdown: remaining)
                
                // Check if warmup period is complete
                if elapsed >= self.warmupDurationSeconds {
                    timer.invalidate()
                    self.warmupTimer = nil
                    self.completeWarmupPeriod()
                }
            }
        }
    }
    
    private func completeWarmupPeriod() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Verify minimum time has passed
            let timeElapsed = Date().timeIntervalSince(self.warmupStartTime ?? Date())
            if timeElapsed < self.warmupDurationSeconds {
                return
            }
            
            // Start stability analysis if not in extended analysis
            if !self.stabilityAnalysisActive && !self.isExtendedWarmupActive {
                self.startStabilityAnalysis()
                return
            }
            
            // Check if we have enough stable buffers
            if self.consecutiveStableBuffers < self.requiredStableBuffers && self.isExtendedWarmupActive {
                self.extendWarmupPeriod()
                return
            }
            
            // Conditions met: minimum time and stability (or timeout)
            self.finalizeWarmupAndNotify()
        }
    }
    
    private func startStabilityAnalysis() {
        logger.recordingEvent("Starting stability analysis after minimum warmup period")
        
        // Clear previous analysis data
        consecutiveStableBuffers = 0
        micBufferIntervals.removeAll()
        sysBufferIntervals.removeAll()
        
        // Mark analysis mode
        stabilityAnalysisActive = true
        isExtendedWarmupActive = true
        stabilityAnalysisStartTime = Date()
        stabilityAttempts = 0
        
        // Update UI to show stability analysis
        warmupProgress = 0.8  // Keep progress high but not complete
        
        // Schedule check after short period
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.checkStabilityAndProceed()
        }
        
        // Set safety timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + maxStabilityAnalysisTime) { [weak self] in
            guard let self = self, self.stabilityAnalysisActive else { return }
            
            logger.recordingEvent("Stability analysis timeout reached, proceeding with recording")
            self.finalizeWarmupAndNotify()
        }
    }
    
    private func checkStabilityAndProceed() {
        guard stabilityAnalysisActive else { return }
        
        // Check if maximum time exceeded
        if let startTime = stabilityAnalysisStartTime,
           Date().timeIntervalSince(startTime) > maxStabilityAnalysisTime {
            logger.recordingEvent("Stability analysis timeout, starting recording")
            finalizeWarmupAndNotify()
            return
        }
        
        // Check stability
        if consecutiveStableBuffers >= requiredStableBuffers {
            logger.recordingEvent("Stability achieved: \(consecutiveStableBuffers) consecutive stable buffers")
            finalizeWarmupAndNotify()
        } else {
            stabilityAttempts += 1
            
            if stabilityAttempts >= maxStabilityAttempts {
                logger.recordingEvent("Maximum stability attempts reached (\(maxStabilityAttempts)), starting recording")
                finalizeWarmupAndNotify()
                return
            }
            
            extendWarmupPeriod()
        }
    }
    
    private func extendWarmupPeriod() {
        logger.recordingEvent("Extending warmup period to improve stability")
        
        // Update UI to show we need more time
        warmupCountdown = 1
        warmupProgress = 0.9
        
        // Schedule new check after short period
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.checkStabilityAndProceed()
        }
    }
    
    private func finalizeWarmupAndNotify() {
        logger.recordingEvent("Finalizing warmup and notifying completion")
        
        // Reset analysis states
        stabilityAnalysisActive = false
        isExtendedWarmupActive = false
        
        // Reset warmup state
        isWarmingUp = false
        isInWarmupPeriod = false
        
        // Complete progress
        warmupProgress = 1.0
        warmupCountdown = 0
        
        // Notify delegate
        delegate?.warmupDidComplete()
        
        logger.recordingEvent("Warmup completed successfully")
    }
    
    private func updateStabilityCount(microphoneStable: Bool, systemStable: Bool? = nil) {
        let isStable: Bool
        
        if let sysStable = systemStable {
            // Both microphone and system audio
            isStable = microphoneStable && sysStable
            logger.debug("Buffer stability - Mic: \(microphoneStable), Sys: \(sysStable), Combined: \(isStable)")
        } else {
            // Microphone only
            isStable = microphoneStable
            logger.debug("Buffer stability - Mic: \(microphoneStable)")
        }
        
        if isStable {
            consecutiveStableBuffers += 1
            logger.debug("Stable buffers: \(consecutiveStableBuffers)/\(requiredStableBuffers)")
        } else {
            consecutiveStableBuffers = 0
            logger.debug("Unstable buffers detected, resetting count")
        }
    }
    
    private func checkBufferIntervalStability(_ intervals: [Double]) -> Bool {
        guard intervals.count >= 3 else { return false }
        
        // Calculate mean and standard deviation
        let mean = intervals.reduce(0, +) / Double(intervals.count)
        let variance = intervals.reduce(0) { $0 + pow($1 - mean, 2) } / Double(intervals.count)
        let stdDev = sqrt(variance)
        
        // Calculate coefficient of variation (CV) - standard deviation divided by mean
        let cv = mean > 0 ? stdDev / mean : 1.0
        
        // Consider stable if coefficient of variation is less than 25%
        let isStable = cv < 0.25
        
        logger.debug("Stability analysis: mean=\(String(format: "%.4f", mean)), stdDev=\(String(format: "%.4f", stdDev)), cv=\(String(format: "%.4f", cv)), stable=\(isStable)")
        
        return isStable
    }
}