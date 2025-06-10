import Foundation
import AVFoundation
import Combine

/// Coordinator principal para orquestrar gravação de áudio usando services especializados
class AudioRecordingCoordinator: ObservableObject {
    
    // MARK: - Published Properties (Interface pública para Views)
    
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var currentDuration: TimeInterval = 0
    @Published var audioLevel: Float = 0.0
    @Published var errorMessage: String?
    @Published var availableInputDevices: [AudioDevice] = []
    @Published var selectedInputDevice: AudioDevice?
    @Published var systemAudioAvailable = false
    @Published var systemAudioEnabled = true
    @Published var isWarmingUp: Bool = false
    @Published var warmupProgress: Double = 0.0
    @Published var warmupCountdown: Int = 3
    
    // MARK: - Private Properties
    
    // Services especializados (injeção de dependência)
    private var microphoneService: MicrophoneCaptureProtocol
    private var systemAudioService: SystemAudioCaptureProtocol
    private let permissionManager: AudioPermissionManager
    private let formatConverter: AudioConverterProtocol
    private let synchronizer: AudioSynchronizerProtocol
    
    // 🔧 NOVO: Services especializados extraídos
    private let audioFileService: AudioFileService
    private let diagnostics = DiagnosticsService()
    private let logger = LoggingService.shared
    
    // Estado da gravação simplificado
    private var currentConfiguration: AudioConfiguration?
    private var currentMeetingId: UUID?
    
    // Timing e controle
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var totalPausedDuration: TimeInterval = 0
    private var pauseStartTime: Date?
    
    // Sincronização
    private var firstMicBufferHostTime: UInt64?
    private var firstSysBufferHostTime: UInt64?
    
    // MARK: - Warmup Properties
    
    private var isInWarmupPeriod: Bool = false
    private var warmupStartTime: Date?
    private let warmupDurationSeconds: TimeInterval = 3.0
    private var warmupTimer: Timer?
    private var isRecordingAfterWarmup: Bool = false
    private var captureStartedDuringWarmup: Bool = false
    
    // Propriedades para análise de estabilidade
    private var consecutiveStableBuffers: Int = 0
    private let requiredStableBuffers: Int = 3
    private var lastMicBufferTime: Double = 0
    private var lastSysBufferTime: Double = 0
    private var micBufferIntervals: [Double] = []
    private var sysBufferIntervals: [Double] = []
    private var isExtendedWarmupActive: Bool = false
    private var stabilityAnalysisActive: Bool = false
    private var stabilityAnalysisStartTime: Date?
    private let maxStabilityAnalysisTime: TimeInterval = 5.0 // Tempo máximo de análise: 5 segundos
    private var stabilityAttempts: Int = 0
    private let maxStabilityAttempts: Int = 3
    
    // MARK: - Initialization
    
    init(
        microphoneService: MicrophoneCaptureProtocol,
        systemAudioService: SystemAudioCaptureProtocol,
        audioFileManager: AudioFileManagerProtocol,
        permissionManager: AudioPermissionManager,
        formatConverter: AudioConverterProtocol,
        synchronizer: AudioSynchronizerProtocol
    ) {
        self.microphoneService = microphoneService
        self.systemAudioService = systemAudioService
        self.permissionManager = permissionManager
        self.formatConverter = formatConverter
        self.synchronizer = synchronizer
        
        // 🔧 NOVO: Inicializar services especializados
        self.audioFileService = AudioFileService(
            audioFileManager: audioFileManager,
            synchronizer: synchronizer
        )
        
        logger.info("AudioRecordingCoordinator initialized", category: .recording)
        
        // Resetar sincronização
        synchronizer.resetSync()
        firstMicBufferHostTime = nil
        firstSysBufferHostTime = nil
        
        setupInitialState()
        setupServiceCallbacks()
    }
    
    // MARK: - Public Methods
    
    /// Inicializar coordinator (carrega dispositivos, detecta capacidades)
    func initialize() async {
        logger.info("Initializing coordinator", category: .recording)
        
        // Log system capabilities
        diagnostics.logSystemCapabilities()
        
        // Carregar dispositivos disponíveis
        await MainActor.run {
            availableInputDevices = microphoneService.availableInputDevices
            selectedInputDevice = microphoneService.selectedInputDevice
        }
        
        // Detectar capacidades de áudio do sistema
        let systemCapabilities = systemAudioService.getSystemAudioCapabilities()
        await MainActor.run {
            systemAudioAvailable = systemCapabilities.isSupported
            
            logger.audioEvent("System audio capabilities", details: [
                "supported": systemCapabilities.isSupported,
                "strategy": systemCapabilities.supportedStrategy.rawValue,
                "macOSVersion": systemCapabilities.macOSVersion,
                "enabledInCoordinator": systemAudioEnabled
            ])
        }
        
        logger.info("Coordinator initialization completed", category: .recording)
    }
    
    /// Solicitar todas as permissões necessárias
    /// - Returns: True se todas as permissões foram concedidas
    func requestPermissions() async -> Bool {
        logger.info("Requesting permissions", category: .recording)
        
        let result = await permissionManager.requestAllPermissions(includeSystemAudio: systemAudioEnabled && systemAudioAvailable)
        
        await MainActor.run {
            if !result.success {
                let errorMessages = result.errors.map { $0.localizedDescription }
                errorMessage = "Permissions denied: \(errorMessages.joined(separator: ", "))"
            } else {
                errorMessage = nil
            }
        }
        
        logger.audioEvent("Permission request result", details: [
            "success": result.success,
            "microphoneGranted": result.microphoneGranted,
            "systemAudioGranted": result.systemAudioGranted
        ])
        
        return result.success
    }
    
    /// Iniciar gravação para uma reunião
    /// - Parameter meeting: Reunião para gravar
    /// - Returns: True se a gravação foi iniciada com sucesso
    func startRecording(for meeting: Meeting) async -> Bool {
        guard !isRecording && !isWarmingUp else { return false }
        
        logger.recordingEvent("Starting recording preparation phase", meetingId: meeting.id)
        
        // Reset diagnostics
        diagnostics.resetCounters()
        
        // Verificar permissões
        guard await requestPermissions() else {
            logger.error("Insufficient permissions", category: .recording)
            return false
        }
        
        // 1. Iniciar período de aquecimento
        await MainActor.run {
            isWarmingUp = true
            warmupProgress = 0.0
            warmupCountdown = Int(warmupDurationSeconds)
            isInWarmupPeriod = true
            warmupStartTime = Date()
            captureStartedDuringWarmup = false
            isRecordingAfterWarmup = false
        }
        
        // 2. Iniciar timer de contagem regressiva
        startWarmupTimer()
        
        do {
            // 3. Configurar ID da reunião
            currentMeetingId = meeting.id
            
            // 4. Determinar configuração otimizada
            let configuration = determineOptimalConfiguration()
            currentConfiguration = configuration
            
            // Log configuration
            diagnostics.logAudioConfiguration(configuration)
            
            // 5. Configurar arquivos de áudio
            try await audioFileService.setupAudioFiles(
                for: meeting.id,
                configuration: configuration
            )
            
            // 6. Iniciar captura do microfone
            try await startMicrophoneCapture(configuration: configuration)
            
            // 7. Iniciar captura do áudio do sistema se disponível e habilitado
            let systemAudioAvailable = await systemAudioService.isSystemAudioAvailable()
            await MainActor.run {
                self.systemAudioAvailable = systemAudioAvailable
            }
            
            if systemAudioEnabled && systemAudioAvailable {
                logger.audioEvent("Starting system audio capture during warmup")
                try await startSystemAudioCapture(configuration: configuration)
                logger.audioEvent("System audio capture started during warmup")
            } else {
                logger.audioEvent("System audio capture skipped", details: [
                    "enabled": systemAudioEnabled,
                    "available": systemAudioAvailable
                ])
            }
            
            // 8. Marcar que a captura foi iniciada durante o warmup
            captureStartedDuringWarmup = true
            logger.recordingEvent("Capture started during warmup phase", meetingId: currentMeetingId)
            
            // Start diagnostics monitoring
            diagnostics.performBufferCheck()
            
            return true
            
        } catch {
            logger.error("Failed to start recording", error: error, category: .recording)
            await MainActor.run {
                errorMessage = "Failed to start recording: \(error.localizedDescription)"
                isWarmingUp = false
                isInWarmupPeriod = false
                warmupTimer?.invalidate()
                warmupTimer = nil
            }
            
            await cleanupRecording()
            return false
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func startAudioCapture(configuration: AudioConfiguration) async throws {
        // Start microphone capture
        try await startMicrophoneCapture(configuration: configuration)
        
        // Start system audio capture if enabled
        if systemAudioEnabled && systemAudioAvailable {
            logger.audioEvent("Starting system audio capture")
            try await startSystemAudioCapture(configuration: configuration)
            logger.audioEvent("System audio capture started")
        } else {
            logger.audioEvent("System audio capture skipped", details: [
                "enabled": systemAudioEnabled,
                "available": systemAudioAvailable
            ])
        }
    }
    
    private func updateRecordingState(isRecording: Bool) async {
        await MainActor.run {
            self.isRecording = isRecording
            self.isPaused = false
            
            if isRecording {
                recordingStartTime = Date()
                totalPausedDuration = 0
                currentDuration = 0
                errorMessage = nil
                startTimer()
            } else {
                stopTimer()
            }
        }
    }
    
    /// Pausar gravação
    func pauseRecording() {
        guard isRecording && !isPaused else { return }
        
        logger.recordingEvent("Pausing recording", meetingId: currentMeetingId)
        
        Task {
            await microphoneService.pauseCapture()
            if systemAudioEnabled {
                await systemAudioService.pauseCapture()
            }
        }
        
        isPaused = true
        pauseStartTime = Date()
        stopTimer()
        
        logger.recordingEvent("Recording paused", meetingId: currentMeetingId)
    }
    
    /// Retomar gravação
    func resumeRecording() {
        guard isRecording && isPaused else { return }
        
        logger.recordingEvent("Resuming recording", meetingId: currentMeetingId)
        
        if let pauseStart = pauseStartTime {
            totalPausedDuration += Date().timeIntervalSince(pauseStart)
        }
        
        Task {
            await microphoneService.resumeCapture()
            if systemAudioEnabled {
                await systemAudioService.resumeCapture()
            }
        }
        
        isPaused = false
        pauseStartTime = nil
        startTimer()
        
        logger.recordingEvent("Recording resumed", meetingId: currentMeetingId)
    }
    
    /// Parar gravação
    /// - Returns: Tupla com caminho do arquivo e duração
    func stopRecording() async -> (audioPath: String?, duration: TimeInterval) {
        // Se estiver no período de aquecimento, cancelar o processo
        if isWarmingUp || isInWarmupPeriod {
            logger.recordingEvent("Cancelando gravação durante período de aquecimento")
            
            // Cancelar timers
            warmupTimer?.invalidate()
            warmupTimer = nil
            
            // Resetar estados
            await MainActor.run {
                isWarmingUp = false
                isInWarmupPeriod = false
                stabilityAnalysisActive = false
                isExtendedWarmupActive = false
            }
            
            // Parar serviços de captura
            await microphoneService.stopCapture()
            await systemAudioService.stopCapture()
            
            // Limpar recursos
            await cleanupRecording()
            
            return (nil, 0)
        }
        
        // Código existente para parar gravação normal
        guard isRecording else { return (nil, 0) }
        
        logger.recordingEvent("Stopping recording", meetingId: currentMeetingId)
        
        let finalDuration = calculateFinalDuration()
        
        // 1. Stop audio capture and wait for it to complete
        await microphoneService.stopCapture()
        await systemAudioService.stopCapture()
        
        // 2. Finalize files to ensure all buffers are written
        await audioFileService.finalizeFiles()
        
        // 3. ADICIONADO: Aguardar um pequeno intervalo para garantir que o sistema operacional tenha tempo
        // de completar operações de I/O e liberar os arquivos totalmente
        print("[DEBUG] Aguardando um momento para garantir que os arquivos estejam disponíveis...")
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 segundo
        
        // 4. Now, process the complete files
        let finalAudioPath = audioFileService.processRecordingFiles()
        
        // 5. ADICIONADO: Agora sim podemos limpar o estado do AudioFileService
        audioFileService.cleanupState()
        
        // 6. Cleanup internal state
        await cleanupRecording()
        
        // 7. Update state on main thread
        await updateRecordingState(isRecording: false)
        await MainActor.run {
            currentDuration = finalDuration
        }
        
        logger.recordingEvent("Recording stopped", meetingId: currentMeetingId)
        logger.performance("Recording duration", duration: finalDuration)
        
        return (finalAudioPath, finalDuration)
    }
    
    // MARK: - Device Management (Delegated to MicrophoneService)
    
    /// Recarregar dispositivos de entrada disponíveis
    func loadAvailableDevices() {
        microphoneService.loadAvailableDevices()
        availableInputDevices = microphoneService.availableInputDevices
        
        // Atualizar dispositivo selecionado se necessário
        if selectedInputDevice == nil {
            selectedInputDevice = microphoneService.selectedInputDevice
        }
        
        logger.audioEvent("Devices reloaded", details: [
            "count": availableInputDevices.count
        ])
    }
    
    /// Selecionar dispositivo de entrada
    func selectInputDevice(_ device: AudioDevice) {
        selectedInputDevice = device
        microphoneService.selectInputDevice(device)
        
        logger.audioEvent("Input device selected", details: [
            "deviceName": device.name
        ])
    }
    
    /// Configurar se o áudio do sistema deve ser habilitado
    func setSystemAudioEnabled(_ enabled: Bool) {
        systemAudioEnabled = enabled
        
        logger.audioEvent("System audio setting changed", details: [
            "enabled": enabled,
            "available": systemAudioAvailable
        ])
    }
    
    // MARK: - Private Methods
    
    private func setupInitialState() {
        logger.debug("Setting up initial state", category: .recording)
        // Estado inicial já definido nas @Published properties
    }
    
    private func setupServiceCallbacks() {
        logger.debug("Setting up service callbacks", category: .recording)
        
        // Callback para áudio do microfone
        microphoneService.onAudioReceived = { [weak self] buffer, hostTime in
            self?.handleMicrophoneAudio(buffer, hostTime: hostTime)
        }
        
        // Callback para áudio do sistema
        systemAudioService.onAudioReceived = { [weak self] buffer, hostTime in
            self?.handleSystemAudio(buffer, hostTime: hostTime)
        }
    }
    
    private func determineOptimalConfiguration() -> AudioConfiguration {
        // Determinar estratégia baseada em preferências e capacidades
        let strategy: AudioCaptureStrategy
        if systemAudioEnabled && systemAudioAvailable {
            strategy = .screenCaptureKit
        } else {
            strategy = .microphoneOnly
        }
        
        return AudioConfiguration(
            captureStrategy: strategy,
            microphoneConfig: MicrophoneConfiguration(inputDevice: selectedInputDevice),
            systemAudioConfig: systemAudioEnabled ? SystemAudioConfiguration.default : nil
        )
    }
    
    private func startMicrophoneCapture(configuration: AudioConfiguration) async throws {
        logger.audioEvent("Starting microphone capture")
        try await microphoneService.startCapture(configuration: configuration)
        logger.audioEvent("Microphone capture started")
    }
    
    private func startSystemAudioCapture(configuration: AudioConfiguration) async throws {
        logger.audioEvent("Starting system audio capture")
        try await systemAudioService.startCapture(configuration: configuration)
        logger.audioEvent("System audio capture started")
    }
    
    private func handleMicrophoneAudio(_ buffer: AVAudioPCMBuffer, hostTime: UInt64) {
        // Se estiver no período de aquecimento, analisar estabilidade
        if isInWarmupPeriod {
            // Apenas monitorar nível de áudio para feedback, mas não gravar
            DispatchQueue.main.async { [weak self] in
                self?.updateAudioLevel(from: buffer)
            }
            
            // Se estamos em análise de estabilidade, verificar qualidade do buffer
            if stabilityAnalysisActive {
                analyzeMicBufferStability(buffer)
            }
            
            return
        }
        
        guard isRecording && !isPaused else { return }
        
        // Inicializar sincronização no primeiro buffer após o período de aquecimento
        if isRecordingAfterWarmup && firstMicBufferHostTime == nil {
            firstMicBufferHostTime = hostTime
            tryInitializeSynchronizer()
        }
        
        // Write to file via AudioFileService
        audioFileService.writeMicrophoneAudio(buffer)
        
        // Update audio level for visual feedback
        DispatchQueue.main.async { [weak self] in
            self?.updateAudioLevel(from: buffer)
        }
    }
    
    private func handleSystemAudio(_ buffer: AVAudioPCMBuffer, hostTime: UInt64) {
        // Se estiver no período de aquecimento, analisar estabilidade
        if isInWarmupPeriod {
            // Se estamos em análise de estabilidade, verificar qualidade do buffer
            if stabilityAnalysisActive {
                analyzeSystemBufferStability(buffer)
            }
            
            return
        }
        
        guard isRecording && !isPaused else { return }
        
        // Inicializar sincronização no primeiro buffer após o período de aquecimento
        if isRecordingAfterWarmup && firstSysBufferHostTime == nil {
            firstSysBufferHostTime = hostTime
            tryInitializeSynchronizer()
        }
        
        // Write to file via AudioFileService
        audioFileService.writeSystemAudio(buffer)
    }
    
    private func tryInitializeSynchronizer() {
        guard let micTime = firstMicBufferHostTime, let sysTime = firstSysBufferHostTime else {
            return
        }
        
        synchronizer.initializeSync(systemTime: sysTime, microphoneTime: micTime)
    }
    
    private func cleanupRecording() async {
        logger.debug("Cleaning up recording", category: .recording)
        
        currentConfiguration = nil
        currentMeetingId = nil
    }
    
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
    
    private func updateAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        let channelDataArray = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
        let rms = sqrt(channelDataArray.map { $0 * $0 }.reduce(0, +) / Float(channelDataArray.count))
        let avgPower = 20 * log10(max(rms, 1e-6))
        let normalizedPower = max(0, min(1, (avgPower + 80) / 80))
        
        audioLevel = normalizedPower
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
    
    // MARK: - Warmup Methods
    
    private func startWarmupTimer() {
        // Parar timer existente se houver
        warmupTimer?.invalidate()
        
        // Criar novo timer na UI thread
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
                
                // Atualizar UI
                self.warmupProgress = progress
                if self.warmupCountdown != remaining {
                    self.warmupCountdown = remaining
                }
                
                // Verificar se o período de aquecimento terminou
                if elapsed >= self.warmupDurationSeconds {
                    timer.invalidate()
                    self.warmupTimer = nil
                    self.completeWarmupPeriod()
                }
            }
        }
    }
    
    private func completeWarmupPeriod() {
        // Executar na UI thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Verificar se o tempo mínimo de 3 segundos passou
            let timeElapsed = Date().timeIntervalSince(warmupStartTime ?? Date())
            if timeElapsed < warmupDurationSeconds {
                // Ainda não atingimos o tempo mínimo
                return
            }
            
            // Iniciar análise de estabilidade se não estiver em análise estendida
            if !stabilityAnalysisActive && !isExtendedWarmupActive {
                startStabilityAnalysis()
                return
            }
            
            // Verificar se temos buffers estáveis suficientes
            if consecutiveStableBuffers < requiredStableBuffers && isExtendedWarmupActive {
                // Ainda não atingimos estabilidade, continuar monitorando
                extendWarmupPeriod()
                return
            }
            
            // Condições atendidas: tempo mínimo e estabilidade (ou timeout de análise)
            finalizeWarmupAndStartRecording()
        }
    }
    
    private func startStabilityAnalysis() {
        logger.recordingEvent("Iniciando análise de estabilidade após período mínimo de aquecimento")
        
        // Limpar dados de análise anteriores
        consecutiveStableBuffers = 0
        micBufferIntervals.removeAll()
        sysBufferIntervals.removeAll()
        
        // Marcar que estamos em modo de análise
        stabilityAnalysisActive = true
        isExtendedWarmupActive = true
        stabilityAnalysisStartTime = Date()
        stabilityAttempts = 0
        
        // Atualizar UI para mostrar que estamos analisando estabilidade
        warmupProgress = 0.8  // Manter progresso alto mas não completo
        
        // Agendar verificação após um curto período
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.checkStabilityAndProceed()
        }
        
        // Definir timeout de segurança
        DispatchQueue.main.asyncAfter(deadline: .now() + maxStabilityAnalysisTime) { [weak self] in
            guard let self = self, self.stabilityAnalysisActive else { return }
            
            // Se ainda estamos analisando após o tempo máximo, forçar início
            logger.recordingEvent("Timeout de análise de estabilidade atingido, iniciando gravação")
            finalizeWarmupAndStartRecording()
        }
    }
    
    private func checkStabilityAndProceed() {
        // Verificar se já não estamos mais em análise
        guard stabilityAnalysisActive else { return }
        
        // Verificar se excedemos o tempo máximo
        if let startTime = stabilityAnalysisStartTime, 
           Date().timeIntervalSince(startTime) > maxStabilityAnalysisTime {
            logger.recordingEvent("Timeout de análise de estabilidade, iniciando gravação")
            finalizeWarmupAndStartRecording()
            return
        }
        
        // Verificar estabilidade
        if consecutiveStableBuffers >= requiredStableBuffers {
            // Estabilidade alcançada
            logger.recordingEvent("Estabilidade alcançada: \(consecutiveStableBuffers) buffers estáveis consecutivos")
            finalizeWarmupAndStartRecording()
        } else {
            // Incrementar tentativas
            stabilityAttempts += 1
            
            // Verificar número máximo de tentativas
            if stabilityAttempts >= maxStabilityAttempts {
                logger.recordingEvent("Número máximo de tentativas atingido (\(maxStabilityAttempts)), iniciando gravação")
                finalizeWarmupAndStartRecording()
                return
            }
            
            // Estender o período de análise
            extendWarmupPeriod()
        }
    }
    
    private func extendWarmupPeriod() {
        logger.recordingEvent("Estendendo período de aquecimento para melhorar estabilidade")
        
        // Atualizar UI para mostrar que precisamos de mais tempo
        warmupCountdown = 1
        warmupProgress = 0.9
        
        // Agendar nova verificação após um curto período
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.checkStabilityAndProceed()
        }
    }
    
    private func finalizeWarmupAndStartRecording() {
        logger.recordingEvent("Finalizando aquecimento e iniciando gravação")
        
        // Resetar estados de análise
        stabilityAnalysisActive = false
        isExtendedWarmupActive = false
        
        // Resetar estado de aquecimento
        isWarmingUp = false
        isInWarmupPeriod = false
        
        // Se a captura foi iniciada durante o warmup, começar a gravação real
        if captureStartedDuringWarmup {
            isRecording = true
            isRecordingAfterWarmup = true
            recordingStartTime = Date()
            totalPausedDuration = 0
            currentDuration = 0
            errorMessage = nil
            startTimer()
            
            // Resetar o sincronizador para que seja inicializado com buffers estáveis
            synchronizer.resetSync()
            firstMicBufferHostTime = nil
            firstSysBufferHostTime = nil
            
            logger.recordingEvent("Recording started after warmup", meetingId: currentMeetingId)
        }
    }
    
    // MARK: - Buffer Stability Analysis
    
    private func analyzeMicBufferStability(_ buffer: AVAudioPCMBuffer) {
        let currentTime = CACurrentMediaTime()
        
        // Calcular intervalo entre buffers
        if lastMicBufferTime > 0 {
            let interval = currentTime - lastMicBufferTime
            micBufferIntervals.append(interval)
            
            // Manter apenas os últimos 10 intervalos para análise
            if micBufferIntervals.count > 10 {
                micBufferIntervals.removeFirst()
            }
            
            // Verificar estabilidade nos intervalos
            if micBufferIntervals.count >= 3 {
                let isStable = checkBufferIntervalStability(micBufferIntervals)
                if isStable {
                    consecutiveStableBuffers += 1
                    logger.debug("Buffer de microfone estável: \(consecutiveStableBuffers)/\(requiredStableBuffers)")
                } else {
                    consecutiveStableBuffers = 0
                    logger.debug("Buffer de microfone instável, resetando contagem")
                }
            }
        }
        
        lastMicBufferTime = currentTime
    }
    
    private func analyzeSystemBufferStability(_ buffer: AVAudioPCMBuffer) {
        let currentTime = CACurrentMediaTime()
        
        // Calcular intervalo entre buffers
        if lastSysBufferTime > 0 {
            let interval = currentTime - lastSysBufferTime
            sysBufferIntervals.append(interval)
            
            // Manter apenas os últimos 10 intervalos para análise
            if sysBufferIntervals.count > 10 {
                sysBufferIntervals.removeFirst()
            }
            
            // Verificar estabilidade nos intervalos
            if sysBufferIntervals.count >= 3 && micBufferIntervals.count >= 3 {
                let isSysStable = checkBufferIntervalStability(sysBufferIntervals)
                let isMicStable = checkBufferIntervalStability(micBufferIntervals)
                
                if isSysStable && isMicStable {
                    consecutiveStableBuffers += 1
                    logger.debug("Ambos os buffers estáveis: \(consecutiveStableBuffers)/\(requiredStableBuffers)")
                } else {
                    consecutiveStableBuffers = 0
                    logger.debug("Buffers instáveis, resetando contagem. Mic: \(isMicStable), Sys: \(isSysStable)")
                }
            }
        }
        
        lastSysBufferTime = currentTime
    }
    
    private func checkBufferIntervalStability(_ intervals: [Double]) -> Bool {
        guard intervals.count >= 3 else { return false }
        
        // Calcular média e desvio padrão
        let mean = intervals.reduce(0, +) / Double(intervals.count)
        let variance = intervals.reduce(0) { $0 + pow($1 - mean, 2) } / Double(intervals.count)
        let stdDev = sqrt(variance)
        
        // Calcular coeficiente de variação (CV) - desvio padrão dividido pela média
        // Quanto menor o CV, mais estáveis são os intervalos
        let cv = mean > 0 ? stdDev / mean : 1.0
        
        // Relaxar critério: consideramos estável se o coeficiente de variação for menor que 25%
        // (aumentado de 10% para 25% para ser menos restritivo)
        let isStable = cv < 0.25
        
        logger.debug("Análise de estabilidade: média=\(mean), stdDev=\(stdDev), cv=\(cv), estável=\(isStable)")
        
        return isStable
    }
} 