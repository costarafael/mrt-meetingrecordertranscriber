import Foundation
import Combine
import SwiftUI

@MainActor
class MeetingStore: ObservableObject {
    @Published var meetings: [Meeting] = []
    @Published var currentMeeting: Meeting?
    @Published var searchText = ""
    @Published var lastCompletedMeeting: Meeting? // Para navegação automática
    
    // MARK: - Audio State (Delegated to AudioRecordingCoordinator)
    // Estas propriedades são observadas do AudioRecordingCoordinator
    var isRecording: Bool { audioService?.isRecording ?? false }
    var isPaused: Bool { audioService?.isPaused ?? false }
    var currentDuration: TimeInterval { audioService?.currentDuration ?? 0 }
    var audioLevel: Float { audioService?.audioLevel ?? 0.0 }
    var errorMessage: String? { audioService?.errorMessage }
    var availableInputDevices: [AudioDevice] { audioService?.availableInputDevices ?? [] }
    var selectedInputDevice: AudioDevice? { audioService?.selectedInputDevice }
    var systemAudioAvailable: Bool { audioService?.systemAudioAvailable ?? false }
    var systemAudioEnabled: Bool { audioService?.systemAudioEnabled ?? true }
    
    private let dataManager = DataManager()
    
    // 🔧 CORREÇÃO: Usar instância injetada em vez de criar nova
    private var audioService: AudioRecordingCoordinator!
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadMeetings()
    }
    
    // 🔧 NOVO: Método para injetar o audioService
    func setAudioService(_ audioService: AudioRecordingCoordinator) {
        self.audioService = audioService
        setupBindings()
        refreshAudioDevices()
        
        // Inicializar o audioService
        Task {
            await audioService.initialize()
        }
    }
    
    // MARK: - State Management (Simplified - Single Source of Truth)
    
    private func setupBindings() {
        // STATE MANAGEMENT PRINCIPAL: Debounce para evitar updates excessivos
        dataManager.$meetings
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newMeetings in
                guard let self = self else { return }
                
                // Comparar se realmente mudou antes de atualizar
                if !self.areMeetingsEqual(self.meetings, newMeetings) {
                    self.meetings = newMeetings
                    self.objectWillChange.send()
                }
            }
            .store(in: &cancellables)
        
        // 🔧 CORREÇÃO: Observar mudanças no AudioService para atualizar UI
        // Em vez de duplicar estado, observamos as mudanças
        audioService.$isRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        audioService.$currentDuration
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        audioService.$errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    private func areMeetingsEqual(_ lhs: [Meeting], _ rhs: [Meeting]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        
        for i in 0..<lhs.count {
            if lhs[i].id != rhs[i].id ||
               lhs[i].status != rhs[i].status ||
               lhs[i].audioFilePath != rhs[i].audioFilePath ||
               lhs[i].duration != rhs[i].duration {
                return false
            }
        }
        
        return true
    }
    
    private func loadMeetings() {
        // DataManager já carrega as reuniões automaticamente
    }
    
    // MARK: - Data Refresh
    
    func refreshData() {
        dataManager.refreshMeetings()
        refreshAudioDevices()
    }
    
    func refreshAudioDevices() {
        audioService?.loadAvailableDevices()
    }
    
    // MARK: - Audio Device Management
    
    func selectInputDevice(_ device: AudioDevice) {
        audioService?.selectInputDevice(device)
    }
    
    // MARK: - System Audio Control
    
    func setSystemAudioEnabled(_ enabled: Bool) {
        audioService?.setSystemAudioEnabled(enabled)
    }
    
    // MARK: - Recording Actions
    
    func startNewRecording() {
        let meeting = Meeting()
        currentMeeting = meeting
        dataManager.saveMeeting(meeting)
        
        Task {
            let success = await audioService.startRecording(for: meeting)
            if success {
                updateMeetingStatus(meeting.id, status: .recording)
            } else {
                currentMeeting = nil
            }
        }
    }
    
    func pauseRecording() {
        guard let meeting = currentMeeting else { return }
        audioService.pauseRecording()
        updateMeetingStatus(meeting.id, status: .paused)
    }
    
    func resumeRecording() {
        guard let meeting = currentMeeting else { return }
        audioService.resumeRecording()
        updateMeetingStatus(meeting.id, status: .recording)
    }
    
    func stopRecording() async -> Meeting? {
        guard let meeting = currentMeeting else { return nil }
        
        let result = await audioService.stopRecording()
        
        // Atualizar reunião
        if let audioPath = result.audioPath {
            dataManager.updateMeetingAudioPath(for: meeting.id, audioPath: audioPath)
        }
        
        dataManager.updateMeetingDuration(for: meeting.id, duration: result.duration)
        updateMeetingStatus(meeting.id, status: .completed)
        
        currentMeeting = nil
        
        // NAVEGAÇÃO AUTOMÁTICA: Buscar reunião atualizada para navegação
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            
            if let updatedMeeting = self.meetings.first(where: { $0.id == meeting.id }) {
                self.lastCompletedMeeting = updatedMeeting
            }
        }
        
        // Retornar reunião temporária para navegação imediata
        var tempMeeting = meeting
        tempMeeting.status = .completed
        tempMeeting.duration = result.duration
        if let audioPath = result.audioPath {
            tempMeeting.audioFilePath = audioPath
        }
        
        return tempMeeting
    }
    
    // MARK: - Meeting Management
    
    func deleteMeeting(_ meeting: Meeting) async {
        if meeting.id == currentMeeting?.id {
            _ = await stopRecording()
        }
        dataManager.deleteMeeting(meeting)
    }
    
    func deleteAudioArtifacts(for meeting: Meeting) {
        dataManager.deleteAudioArtifacts(for: meeting)
    }
    
    func updateMeetingTitle(_ meetingId: UUID, newTitle: String) {
        dataManager.updateMeetingTitle(for: meetingId, newTitle: newTitle)
    }
    
    func updateMeetingNotes(_ meetingId: UUID, notes: String) {
        dataManager.updateMeetingNotes(for: meetingId, notes: notes)
    }
    
    private func updateMeetingStatus(_ meetingId: UUID, status: MeetingStatus) {
        dataManager.updateMeetingStatus(for: meetingId, status: status)
    }
    
    // MARK: - Search and Filtering
    
    var filteredMeetings: [Meeting] {
        if searchText.isEmpty {
            return meetings
        } else {
            return dataManager.searchMeetings(query: searchText)
        }
    }
    
    func getRecentMeetings(limit: Int = 5) -> [Meeting] {
        return dataManager.getRecentMeetings(limit: limit)
    }
    
    // MARK: - Export
    
    func exportMeeting(_ meeting: Meeting, to url: URL) throws {
        try dataManager.exportMeeting(meeting, to: url)
    }
    
    // MARK: - Utility
    
    func getAudioFileSize(for meeting: Meeting) -> String {
        return dataManager.getAudioFileSize(for: meeting)
    }
    
    func getTotalRecordingTime() -> TimeInterval {
        return dataManager.getTotalRecordingTime()
    }
    
    func getMeetingsCount() -> Int {
        return dataManager.getMeetingsCount()
    }
    
    var currentRecordingDurationFormatted: String {
        // 🔧 CORREÇÃO: Usar formatação centralizada do Meeting
        return TimeInterval.formatDuration(currentDuration)
    }
    
    var hasActiveRecording: Bool {
        return currentMeeting != nil && (isRecording || isPaused)
    }
    
    func clearError() {
        audioService?.errorMessage = nil
    }
    
    func clearLastCompletedMeeting() {
        lastCompletedMeeting = nil
    }
    
    // MARK: - Cleanup
    
    func performMaintenance() {
        dataManager.cleanupOrphanedFiles()
    }
} 