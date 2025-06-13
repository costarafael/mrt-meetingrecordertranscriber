import SwiftUI
import AVFoundation

struct MeetingDetailView: View {
    let meeting: Meeting
    @EnvironmentObject var meetingStore: MeetingStore
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
                MeetingHeaderView(
                    meeting: .constant(currentMeeting),
                    onTitleUpdate: { newTitle in
                        meetingStore.updateMeetingTitle(currentMeeting.id, newTitle: newTitle)
                    }
                )
                
                audioPlayerSection
                
                TranscriptionWorkflowView(meeting: currentMeeting)
                    .environmentObject(meetingStore)
                
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
            // Não fechar a janela de transcrição automaticamente
            // Permitir que o usuário a mantenha aberta se desejar
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
    
    
    private var audioPlayerSection: some View {
        Group {
            if currentMeeting.audioFilePath != nil {
                AudioPlayerSection(
                    audioPlayer: $audioPlayer,
                    isPlaying: $isPlaying,
                    playbackProgress: $playbackProgress,
                    playbackTimer: $playbackTimer,
                    meeting: currentMeeting
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
        cleanupAudioPlayer()
    }
    
    private func exportAudio() {
        Task {
            await ExportService.shared.exportAudio(
                meeting: currentMeeting,
                using: meetingStore
            )
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