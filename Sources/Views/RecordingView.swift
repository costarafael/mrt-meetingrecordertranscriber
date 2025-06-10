import SwiftUI

struct RecordingView: View {
    let meeting: Meeting
    @EnvironmentObject var meetingStore: MeetingStore
    @ObservedObject var audioService: AudioRecordingCoordinator
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack {
                Text("🎙️ Gravando Reunião")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(meeting.title)
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            // Status de captura
            VStack(spacing: 12) {
                HStack {
                    Circle()
                        .fill(audioService.isRecording ? .red : .gray)
                        .frame(width: 12, height: 12)
                    
                    Text(audioService.isRecording ? 
                         (audioService.isPaused ? "Pausado" : "Gravando") : 
                         "Iniciando...")
                        .font(.headline)
                }
                
                // Novo: Status do áudio do sistema
                if audioService.systemAudioAvailable {
                    HStack {
                        Image(systemName: audioService.systemAudioEnabled ? "speaker.wave.2.circle.fill" : "speaker.slash.circle")
                            .foregroundColor(audioService.systemAudioEnabled ? .blue : .orange)
                        
                        Text(audioService.systemAudioEnabled ? "Áudio do Sistema: Ativo" : "Áudio do Sistema: Desabilitado")
                            .font(.caption)
                            .foregroundColor(audioService.systemAudioEnabled ? .blue : .orange)
                    }
                } else {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        
                        Text("Áudio do Sistema: Indisponível (macOS < 13)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                // Status do microfone
                HStack {
                    Image(systemName: "mic.circle.fill")
                        .foregroundColor(.green)
                    
                    Text("Microfone: Ativo")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            // Tempo de gravação
            Text(formatDuration(audioService.currentDuration))
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
            
            // Nível de áudio
            VStack {
                Text("Nível do Microfone")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ProgressView(value: audioService.audioLevel, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .green))
                    .frame(height: 8)
            }
            
            // Controles
            HStack(spacing: 30) {
                if audioService.isRecording {
                    // Pausar/Retomar
                    Button(action: {
                        if audioService.isPaused {
                            audioService.resumeRecording()
                        } else {
                            audioService.pauseRecording()
                        }
                    }) {
                        Image(systemName: audioService.isPaused ? "play.circle.fill" : "pause.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                    }
                    .keyboardShortcut(.space, modifiers: [])
                    
                    // Parar
                    Button(action: {
                        Task {
                            await meetingStore.stopRecording()
                        }
                    }) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.red)
                    }
                } else {
                    // Iniciar - apenas como fallback se não estiver gravando
                    Button(action: {
                        Task {
                            _ = await audioService.startRecording(for: meeting)
                        }
                    }) {
                        Image(systemName: "record.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.red)
                    }
                }
            }
            
            // Toggle para áudio do sistema
            if audioService.systemAudioAvailable {
                Toggle("Capturar áudio do sistema", isOn: $audioService.systemAudioEnabled)
                    .disabled(audioService.isRecording)
                    .padding(.horizontal)
            }
            
            // Erro, se houver
            if let errorMessage = audioService.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

struct AudioLevelView: View {
    let level: Float
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Nível do Áudio")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 2) {
                ForEach(0..<20) { index in
                    Rectangle()
                        .fill(barColor(for: index))
                        .frame(width: 8, height: barHeight(for: index))
                        .animation(.easeInOut(duration: 0.1), value: level)
                }
            }
            .frame(height: 40)
        }
    }
    
    private func barColor(for index: Int) -> Color {
        let threshold = Float(index) / 20.0
        
        if level > threshold {
            if index < 14 {
                return .green
            } else if index < 18 {
                return .yellow
            } else {
                return .red
            }
        } else {
            return Color.gray.opacity(0.3)
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 4
        let maxHeight: CGFloat = 40
        let threshold = Float(index) / 20.0
        
        if level > threshold {
            return baseHeight + (maxHeight - baseHeight) * CGFloat(min(level, 1.0))
        } else {
            return baseHeight
        }
    }
} 