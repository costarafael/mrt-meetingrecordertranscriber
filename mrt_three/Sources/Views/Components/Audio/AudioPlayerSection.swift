import SwiftUI
import AVFoundation

// LoggingService for unified logging
private let logger = LoggingService.shared

struct AudioPlayerSection: View {
    @Binding var audioPlayer: AVAudioPlayer?
    @Binding var isPlaying: Bool
    @Binding var playbackProgress: Double
    @Binding var playbackTimer: Timer?
    let meeting: Meeting
    
    @State private var isLoading = false
    @State private var setupAttempts = 0
    
    var body: some View {
        VStack(spacing: 16) {
            headerView
            
            if isLoading {
                loadingView
            } else if audioPlayer == nil && setupAttempts > 0 {
                errorView
            } else {
                playerView
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            setupAudioPlayerWithRetry()
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack {
            Image(systemName: "waveform")
                .font(.title2)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading) {
                Text("Reprodução de Áudio")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                if let audioPath = meeting.audioFilePath {
                    Text(URL(fileURLWithPath: audioPath).lastPathComponent)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Carregando áudio...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(height: 100)
    }
    
    private var errorView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text("Erro ao carregar áudio")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Button("Tentar Novamente") {
                retrySetup()
            }
            .buttonStyle(.bordered)
        }
        .frame(height: 120)
    }
    
    private var playerView: some View {
        VStack(spacing: 16) {
            // Waveform visualization
            AudioLevelVisualizerView.waveform(progress: playbackProgress)
            
            // Playback Controls
            playbackControls
            
            // Time display
            timeDisplay
        }
    }
    
    private var playbackControls: some View {
        HStack(spacing: 20) {
            Button(action: { seekBackward() }) {
                Image(systemName: "gobackward.15")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .disabled(audioPlayer == nil)
            .help("Voltar 15 segundos")
            
            Button(action: { togglePlayback() }) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 50))
            }
            .buttonStyle(.plain)
            .foregroundColor(audioPlayer == nil ? .gray : .blue)
            .disabled(audioPlayer == nil)
            .help(isPlaying ? "Pausar" : "Reproduzir")
            
            Button(action: { seekForward() }) {
                Image(systemName: "goforward.15")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .disabled(audioPlayer == nil)
            .help("Avançar 15 segundos")
        }
    }
    
    private var timeDisplay: some View {
        HStack {
            Text((audioPlayer?.currentTime ?? 0).mmssFormat)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text((audioPlayer?.duration ?? 0).mmssFormat)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Audio Player Logic
    
    private func setupAudioPlayerWithRetry() {
        isLoading = true
        setupAttempts += 1
        
        // Limpar player anterior
        cleanupAudioPlayer()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(setupAttempts) * 0.2) {
            setupAudioPlayer()
            
            if audioPlayer == nil && setupAttempts < 5 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    setupAudioPlayerWithRetry()
                }
            } else {
                isLoading = false
            }
        }
    }
    
    private func retrySetup() {
        setupAttempts = 0
        cleanupAudioPlayer()
        setupAudioPlayerWithRetry()
    }
    
    private func setupAudioPlayer() {
        guard let audioPath = meeting.audioFilePath else {
            logger.error("[AudioPlayer] Caminho do áudio é nulo para reunião: \(meeting.title)", category: .general)
            isLoading = false
            return
        }
        
        logger.debug("🎵 [AudioPlayer] Tentando carregar áudio de: \(audioPath)", category: .general)
        
        guard FileManager.default.fileExists(atPath: audioPath) else {
            logger.error("[AudioPlayer] Arquivo de áudio não existe: \(audioPath)", category: .general)
            isLoading = false
            return
        }
        
        // Verificar tamanho do arquivo
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: audioPath)
            let fileSize = attributes[FileAttributeKey.size] as? Int64 ?? 0
            logger.debug("[AudioPlayer] Tamanho do arquivo: \(fileSize) bytes", category: .performance)
            
            if fileSize == 0 {
                logger.error("[AudioPlayer] Arquivo de áudio está vazio", category: .general)
                isLoading = false
                return
            }
        } catch {
            logger.error("[AudioPlayer] Erro ao verificar atributos do arquivo: \(error)", category: .general)
        }
        
        do {
            let url = URL(fileURLWithPath: audioPath)
            logger.debug("🔗 [AudioPlayer] URL do áudio: \(url)", category: .general)
            
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.prepareToPlay()
            
            logger.debug("⏱️ [AudioPlayer] Duração detectada: \(newPlayer.duration) segundos", category: .general)
            logger.debug("[AudioPlayer] Sample rate: \(newPlayer.format.sampleRate)Hz", category: .performance)
            logger.debug("[AudioPlayer] Canais: \(newPlayer.format.channelCount)", category: .performance)
            
            guard newPlayer.duration > 0 else {
                logger.error("[AudioPlayer] Duração do áudio é zero", category: .general)
                isLoading = false
                return
            }
            
            audioPlayer = newPlayer
            isLoading = false
            logger.info("[AudioPlayer] Player configurado com sucesso", category: .general)
        } catch {
            logger.error("[AudioPlayer] Erro ao criar AVAudioPlayer: \(error)", category: .general)
            audioPlayer = nil
            isLoading = false
        }
    }
    
    private func togglePlayback() {
        guard let player = audioPlayer else {
            logger.warning("[AudioPlayer] Player é nulo, tentando reconfigurar...", category: .general)
            setupAudioPlayerWithRetry()
            return
        }
        
        logger.debug("🎵 [AudioPlayer] Estado atual - Playing: \(player.isPlaying), Duration: \(player.duration)", category: .general)
        
        guard player.duration > 0 else { 
            logger.error("[AudioPlayer] Player tem duração zero", category: .general)
            return 
        }
        
        if isPlaying {
            logger.debug("⏸️ [AudioPlayer] Pausando reprodução...", category: .general)
            player.pause()
            playbackTimer?.invalidate()
        } else {
            logger.debug("▶️ [AudioPlayer] Iniciando reprodução...", category: .general)
            let success = player.play()
            logger.debug("[AudioPlayer] Resultado do play(): \(success)", category: .performance)
            
            if success {
                startProgressTimer()
            } else {
                logger.error("[AudioPlayer] Falha ao iniciar reprodução", category: .general)
                setupAudioPlayerWithRetry()
                return
            }
        }
        
        isPlaying.toggle()
        logger.debug("Estado alterado para isPlaying: \(isPlaying)", category: .general)
    }
    
    private func startProgressTimer() {
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            updateProgress()
        }
    }
    
    private func updateProgress() {
        guard let player = audioPlayer else { return }
        
        if player.isPlaying {
            playbackProgress = player.currentTime / player.duration
        } else {
            playbackTimer?.invalidate()
            isPlaying = false
        }
    }
    
    private func seekForward() {
        guard let player = audioPlayer else { return }
        player.currentTime = min(player.currentTime + 15, player.duration)
    }
    
    private func seekBackward() {
        guard let player = audioPlayer else { return }
        player.currentTime = max(player.currentTime - 15, 0)
    }
    
    private func cleanupAudioPlayer() {
        audioPlayer?.stop()
        playbackTimer?.invalidate()
        audioPlayer = nil
        isPlaying = false
        playbackProgress = 0
    }
    
}


#Preview {
    AudioPlayerSection(
        audioPlayer: .constant(nil),
        isPlaying: .constant(false),
        playbackProgress: .constant(0.3),
        playbackTimer: .constant(nil),
        meeting: Meeting()
    )
    .frame(width: 400)
    .padding()
}