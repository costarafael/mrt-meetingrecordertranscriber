import SwiftUI
import AVFoundation

struct MeetingDetailView: View {
    let meeting: Meeting
    @EnvironmentObject var meetingStore: MeetingStore
    @State private var editingTitle = false
    @State private var titleText = ""
    @State private var notesText = ""
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var playbackProgress: Double = 0
    @State private var playbackTimer: Timer?
    @State private var showingExportPanel = false
    @State private var showingDeleteConfirmation = false
    
    // Estado reativo para a reunião atual - SIMPLIFICADO
    private var currentMeeting: Meeting {
        meetingStore.meetings.first { $0.id == meeting.id } ?? meeting
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                audioPlayerSection
                meetingInfoSection
                notesSection
                actionButtonsSection
            }
            .padding()
        }
        .navigationTitle("Detalhes da Reunião")
        .onAppear {
            setupInitialState()
        }
        .onDisappear {
            cleanupAudioPlayer()
        }
        .confirmationDialog("Excluir Reunião", isPresented: $showingDeleteConfirmation) {
            Button("Excluir", role: .destructive) {
                Task {
                    await meetingStore.deleteMeeting(currentMeeting)
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Tem certeza que deseja excluir esta reunião? Esta ação não pode ser desfeita.")
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                if editingTitle {
                    TextField("Título da reunião", text: $titleText)
                        .textFieldStyle(.roundedBorder)
                        .font(.title2)
                        .onSubmit {
                            saveTitleEdit()
                        }
                } else {
                    Text(currentMeeting.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Button("Editar") {
                        titleText = currentMeeting.title
                        editingTitle = true
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            HStack {
                StatusBadge(status: currentMeeting.status)
                Spacer()
                VStack(alignment: .trailing) {
                    Text(currentMeeting.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(currentMeeting.formattedDuration)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var audioPlayerSection: some View {
        Group {
            if currentMeeting.audioFilePath != nil {
                AudioPlayerView(
                    meeting: currentMeeting,
                    isPlaying: $isPlaying,
                    progress: $playbackProgress,
                    audioPlayer: $audioPlayer,
                    playbackTimer: $playbackTimer
                )
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "waveform.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("Nenhum áudio disponível")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Esta reunião não possui gravação de áudio.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 150)
                .frame(maxWidth: .infinity)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    private var meetingInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Informações")
                    .font(.headline)
                Spacer()
            }
            
            InfoRowView(title: "Criada em", value: DateFormatter.meetingTitle.string(from: currentMeeting.createdAt))
            InfoRowView(title: "Duração", value: currentMeeting.formattedDuration)
            InfoRowView(title: "Status", value: currentMeeting.status.displayName)
            
            if currentMeeting.audioFilePath != nil {
                InfoRowView(title: "Tamanho do arquivo", value: meetingStore.getAudioFileSize(for: currentMeeting))
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Anotações")
                    .font(.headline)
                Spacer()
            }
            
            TextEditor(text: $notesText)
                .frame(minHeight: 120)
                .scrollContentBackground(.hidden)
                .background(Color(NSColor.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .onChange(of: notesText) { newValue in
                    meetingStore.updateMeetingNotes(currentMeeting.id, notes: newValue)
                }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                if currentMeeting.audioFilePath != nil {
                    Button("Exportar Áudio") {
                        exportAudio()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Excluir Áudio") {
                        meetingStore.deleteAudioArtifacts(for: currentMeeting)
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            Button("Excluir Reunião") {
                showingDeleteConfirmation = true
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
        }
        .padding()
    }
    
    private func setupInitialState() {
        notesText = currentMeeting.notes
        titleText = currentMeeting.title
        cleanupAudioPlayer()
    }
    
    private func saveTitleEdit() {
        meetingStore.updateMeetingTitle(currentMeeting.id, newTitle: titleText)
        editingTitle = false
    }
    
    private func exportAudio() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.audio]
        panel.nameFieldStringValue = "\(currentMeeting.title).m4a"
        
        if panel.runModal() == .OK, let url = panel.url {
            try? meetingStore.exportMeeting(currentMeeting, to: url)
        }
    }
    
    private func cleanupAudioPlayer() {
        audioPlayer?.stop()
        playbackTimer?.invalidate()
        audioPlayer = nil
        isPlaying = false
        playbackProgress = 0
    }
}

struct AudioPlayerView: View {
    let meeting: Meeting
    @Binding var isPlaying: Bool
    @Binding var progress: Double
    @Binding var audioPlayer: AVAudioPlayer?
    @Binding var playbackTimer: Timer?
    @State private var isLoading = false
    @State private var setupAttempts = 0
    
    var body: some View {
        VStack(spacing: 16) {
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
            // Waveform visualization placeholder
            HStack(spacing: 2) {
                ForEach(0..<50, id: \.self) { index in
                    Rectangle()
                        .fill(index < Int(progress * 50) ? Color.blue : .gray.opacity(0.3))
                        .frame(width: 3, height: CGFloat.random(in: 8...40))
                        .animation(.easeInOut(duration: 0.1), value: progress)
                }
            }
            .frame(height: 50)
            
            // Playback Controls
            HStack(spacing: 20) {
                Button(action: { seekBackward() }) {
                    Image(systemName: "gobackward.15")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .disabled(audioPlayer == nil)
                
                Button(action: { togglePlayback() }) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 50))
                }
                .buttonStyle(.plain)
                .foregroundColor(audioPlayer == nil ? .gray : .blue)
                .disabled(audioPlayer == nil)
                
                Button(action: { seekForward() }) {
                    Image(systemName: "goforward.15")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .disabled(audioPlayer == nil)
            }
            
            // Progress
            HStack {
                Text(formatTime(audioPlayer?.currentTime ?? 0))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(formatTime(audioPlayer?.duration ?? 0))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func setupAudioPlayerWithRetry() {
        isLoading = true
        setupAttempts += 1
        
        // Limpar player anterior
        audioPlayer?.stop()
        audioPlayer = nil
        
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
        audioPlayer?.stop()
        audioPlayer = nil
        setupAudioPlayerWithRetry()
    }
    
    private func setupAudioPlayer() {
        guard let audioPath = meeting.audioFilePath else {
            print("❌ Caminho do áudio é nulo para reunião: \(meeting.title)")
            isLoading = false
            return
        }
        
        print("🎵 Tentando carregar áudio de: \(audioPath)")
        
        guard FileManager.default.fileExists(atPath: audioPath) else {
            print("❌ Arquivo de áudio não existe: \(audioPath)")
            isLoading = false
            return
        }
        
        // Verificar tamanho do arquivo
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: audioPath)
            let fileSize = attributes[FileAttributeKey.size] as? Int64 ?? 0
            print("📊 Tamanho do arquivo: \(fileSize) bytes")
            
            if fileSize == 0 {
                print("❌ Arquivo de áudio está vazio")
                isLoading = false
                return
            }
        } catch {
            print("❌ Erro ao verificar atributos do arquivo: \(error)")
        }
        
        do {
            let url = URL(fileURLWithPath: audioPath)
            print("🔗 URL do áudio: \(url)")
            
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.prepareToPlay()
            
            print("⏱️ Duração detectada: \(newPlayer.duration) segundos")
            print("📊 Sample rate do player: \(newPlayer.format.sampleRate)Hz")
            print("📊 Canais do player: \(newPlayer.format.channelCount)")
            print("📊 Formato do player: \(newPlayer.format.description)")
            
            guard newPlayer.duration > 0 else {
                print("❌ Duração do áudio é zero")
                isLoading = false
                return
            }
            
            audioPlayer = newPlayer
            isLoading = false
            print("✅ Player de áudio configurado com sucesso")
        } catch {
            print("❌ Erro ao criar AVAudioPlayer: \(error)")
            audioPlayer = nil
            isLoading = false
        }
    }
    
    private func togglePlayback() {
        guard let player = audioPlayer else {
            print("⚠️ Player é nulo, tentando reconfigurar...")
            setupAudioPlayerWithRetry()
            return
        }
        
        print("🎵 Estado atual - Playing: \(player.isPlaying), Duration: \(player.duration)")
        
        guard player.duration > 0 else { 
            print("❌ Player tem duração zero")
            return 
        }
        
        if isPlaying {
            print("⏸️ Pausando reprodução...")
            player.pause()
            playbackTimer?.invalidate()
        } else {
            print("▶️ Iniciando reprodução...")
            let success = player.play()
            print("📊 Resultado do play(): \(success)")
            
            if success {
                startProgressTimer()
            } else {
                print("❌ Falha ao iniciar reprodução")
                // Tentar reconfigurar o player
                setupAudioPlayerWithRetry()
                return
            }
        }
        
        isPlaying.toggle()
        print("🔄 Estado alterado para isPlaying: \(isPlaying)")
    }
    
    private func startProgressTimer() {
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            updateProgress()
        }
    }
    
    private func updateProgress() {
        guard let player = audioPlayer else { return }
        
        if player.isPlaying {
            progress = player.currentTime / player.duration
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
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct InfoRowView: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
} 