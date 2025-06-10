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
            
            Button(action: {
                Task {
                    // 🔧 CORREÇÃO: Fluxo simplificado para WelcomeView
                    showingRecordingView = true
                    
                    meetingStore.startNewRecording()
                    
                    // Aguardar reunião ser criada
                    for _ in 0..<50 {
                        if let meeting = meetingStore.currentMeeting {
                            let success = await audioService.startRecording(for: meeting)
                            if !success {
                                showingRecordingView = false
                            }
                            break
                        }
                        
                        try? await Task.sleep(nanoseconds: 100_000_000)
                    }
                    
                    if meetingStore.currentMeeting == nil {
                        showingRecordingView = false
                    }
                }
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