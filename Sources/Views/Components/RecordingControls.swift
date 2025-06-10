import SwiftUI
import Foundation

struct RecordingControls: View {
    @ObservedObject var viewModel: RecordingViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // Mostrar contagem regressiva se estiver em aquecimento
            if viewModel.isWarmingUp {
                warmupCountdownView
            } else {
                recordingStatusView
            }
            
            // Controles primários
            HStack(spacing: 40) {
                if viewModel.isRecording || viewModel.isWarmingUp {
                    // Botão de pausa/retomar
                    Button(action: {
                        if viewModel.isPaused {
                            viewModel.resumeRecording()
                        } else {
                            viewModel.pauseRecording()
                        }
                    }) {
                        Image(systemName: viewModel.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.blue)
                            .clipShape(Circle())
                    }
                    .disabled(viewModel.isWarmingUp)
                    
                    // Botão de parar gravação
                    Button(action: {
                        Task {
                            await viewModel.stopRecording()
                        }
                    }) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                    // Permitir o cancelamento mesmo durante o aquecimento
                    .opacity(viewModel.isWarmingUp ? 0.8 : 1.0)
                } else {
                    // Botão de iniciar gravação
                    Button(action: {
                        // Criar uma reunião usando o inicializador correto
                        let meeting = Meeting(title: "Nova Reunião")
                        viewModel.startRecording(for: meeting)
                    }) {
                        Image(systemName: "record.circle")
                            .font(.system(size: 36))
                            .foregroundColor(.white)
                            .frame(width: 70, height: 70)
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                    .disabled(viewModel.isWarmingUp)
                }
            }
            
            // Nível de áudio
            AudioLevelIndicator(level: viewModel.audioLevel)
                .frame(height: 20)
                .padding(.horizontal)
        }
    }
    
    // Visualização da contagem regressiva durante o aquecimento
    private var warmupCountdownView: some View {
        VStack(spacing: 8) {
            Text(warmupCountdownTitle)
                .font(.headline)
                .foregroundColor(.primary)
            
            if viewModel.warmupCountdown > 0 {
                Text("\(viewModel.warmupCountdown)")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.primary)
            } else {
                // Mostrar indicador de atividade quando estiver na fase de análise
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
                    .padding(.vertical, 8)
            }
            
            ProgressView(value: viewModel.warmupProgress)
                .progressViewStyle(LinearProgressViewStyle())
                .frame(width: 200)
                .tint(.blue)
            
            Text(warmupStatusText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // Texto do título adaptativo com base no estado
    private var warmupCountdownTitle: String {
        if viewModel.warmupCountdown <= 1 && viewModel.warmupProgress > 0.7 {
            return "Calibrando sistema..."
        } else {
            return "Preparando gravação..."
        }
    }
    
    // Texto de status adaptativo com base no estado
    private var warmupStatusText: String {
        if viewModel.warmupCountdown <= 1 && viewModel.warmupProgress > 0.7 {
            return "Analisando estabilidade do áudio..."
        } else {
            return "Estabilizando áudio..."
        }
    }
    
    // Visualização do status de gravação
    private var recordingStatusView: some View {
        VStack {
            if viewModel.isRecording {
                HStack(spacing: 8) {
                    Circle()
                        .fill(viewModel.isPaused ? Color.orange : Color.red)
                        .frame(width: 12, height: 12)
                    
                    Text(viewModel.isPaused ? "Pausado" : "Gravando")
                        .font(.headline)
                        .foregroundColor(viewModel.isPaused ? .orange : .red)
                    
                    Text(viewModel.durationText)
                        .font(.title2)
                        .monospacedDigit()
                        .foregroundColor(.primary)
                }
            } else {
                Text("Pronto para gravar")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
        }
        .padding()
    }
}

struct AudioLevelIndicator: View {
    var level: Float
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .cornerRadius(5)
                
                Rectangle()
                    .fill(levelColor)
                    .frame(width: CGFloat(level) * geometry.size.width)
                    .cornerRadius(5)
            }
        }
    }
    
    private var levelColor: Color {
        if level > 0.8 {
            return .red
        } else if level > 0.5 {
            return .orange
        } else {
            return .green
        }
    }
}

struct RecordingControls_Previews: PreviewProvider {
    static var previews: some View {
        // Crie um view model mock para a pré-visualização
        let coordinator = AudioRecordingCoordinator(
            microphoneService: MicrophoneCaptureService(),
            systemAudioService: SystemAudioCaptureService(),
            audioFileManager: AudioFileManager(),
            permissionManager: AudioPermissionManager(),
            formatConverter: AudioFormatConverter(),
            synchronizer: AudioSynchronizer()
        )
        let viewModel = RecordingViewModel(coordinator: coordinator)
        
        RecordingControls(viewModel: viewModel)
            .previewLayout(.sizeThatFits)
            .padding()
    }
} 