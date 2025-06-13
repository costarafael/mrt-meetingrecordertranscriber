import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var meetingStore: MeetingStore
    @EnvironmentObject var audioService: AudioRecordingCoordinator
    @Binding var selectedMeeting: Meeting?
    @Binding var showingRecordingView: Bool
    @Binding var showingAudioSettings: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header com botão de nova gravação
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Meeting Recorder")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("\(meetingStore.getMeetingsCount()) reuniões")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Botão de configurações de áudio
                    Button(action: {
                        showingAudioSettings = true
                    }) {
                        Image(systemName: "gear")
                            .font(.title3)
                    }
                    .buttonStyle(.borderless)
                    .help("Configurações de Áudio")
                }
                
                Button(action: {
                    if audioService.isRecording {
                        showingRecordingView = true
                        selectedMeeting = meetingStore.currentMeeting
                    } else {
                        selectedMeeting = nil
                        showingRecordingView = true
                        
                        meetingStore.startNewRecordingWorkflow(
                            onSuccess: { meeting in
                                selectedMeeting = meeting
                            },
                            onFailure: {
                                showingRecordingView = false
                                selectedMeeting = nil
                            }
                        )
                    }
                }) {
                    HStack {
                        Image(systemName: audioService.isRecording ? "pause.circle.fill" : "record.circle")
                        Text(audioService.isRecording ? "Continuar Gravação" : "Nova Gravação")
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                // Status do dispositivo de áudio
                if let device = audioService.selectedInputDevice {
                    HStack {
                        Image(systemName: "mic")
                            .foregroundColor(.secondary)
                        Text(device.name)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        if audioService.systemAudioAvailable && audioService.systemAudioEnabled {
                            Image(systemName: "speaker.wave.2")
                                .foregroundColor(.green)
                                .help("Áudio do sistema ativo")
                        }
                    }
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Barra de busca
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Buscar reuniões...", text: $meetingStore.searchText)
                    .textFieldStyle(.plain)
                
                if !meetingStore.searchText.isEmpty {
                    Button("Limpar") {
                        meetingStore.searchText = ""
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Lista de reuniões
            List(selection: $selectedMeeting) {
                ForEach(meetingStore.filteredMeetings) { meeting in
                    MeetingRowView(meeting: meeting)
                        .tag(meeting)
                        .id(meeting.id)
                }
            }
            .listStyle(.sidebar)
            .refreshable {
                meetingStore.refreshData()
            }
            .onReceive(meetingStore.$meetings) { _ in
                // Force List to refresh
            }
            .id(meetingStore.meetings.count)
        }
        .frame(minWidth: 300)
    }
} 