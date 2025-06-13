import SwiftUI

struct WelcomeView: View {
    @Binding var showingRecordingView: Bool
    @EnvironmentObject var meetingStore: MeetingStore
    @EnvironmentObject var audioService: AudioRecordingCoordinator
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                Image(systemName: "record.circle")
                    .font(.system(size: 80))
                    .foregroundColor(.accentColor)
                
                Text("Bem-vindo ao Meeting Recorder")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Grave suas reuniões com facilidade e organize todas as suas gravações em um só lugar.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }
            
            // MARK: - Configurações de Áudio
            VStack(spacing: 12) {
                Text("🎧 Configurações de Captura de Áudio")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Gravar com Core Audio Tap", isOn: $meetingStore.useCoreAudioTap)
                        .toggleStyle(.checkbox)
                        .help("Usa Core Audio Tap real via Helper Tool para captura direta do áudio do sistema. Requer macOS 13+ e instalação automática da Helper Tool.")
                    
                    Text(meetingStore.useCoreAudioTap ? "✅ Core Audio Tap ativo - Captura real do sistema" : "📡 ScreenCaptureKit ativo - Captura padrão")
                        .font(.caption)
                        .foregroundColor(meetingStore.useCoreAudioTap ? .green : .secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                .frame(maxWidth: 400)
            }
            
            Button(action: {
                showingRecordingView = true
                
                meetingStore.startNewRecordingWorkflow(
                    onSuccess: { _ in
                        // Gravação iniciada com sucesso, já está na RecordingView
                    },
                    onFailure: {
                        showingRecordingView = false
                    }
                )
            }) {
                HStack {
                    Image(systemName: "record.circle.fill")
                    Text("Iniciar Nova Gravação")
                }
                .frame(width: 200, height: 44)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            if !meetingStore.meetings.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Reuniões Recentes")
                        .font(.headline)
                    
                    VStack(spacing: 8) {
                        ForEach(meetingStore.getRecentMeetings()) { meeting in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(meeting.title)
                                        .font(.subheadline)
                                    Text(meeting.formattedDate)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Text(meeting.formattedDuration)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if meeting.audioFilePath != nil {
                                    Image(systemName: "waveform")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .frame(maxWidth: 400)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.textBackgroundColor))
    }
} 