import Foundation
import Combine

class DataManager: ObservableObject {
    @Published var meetings: [Meeting] = []
    
    private let userDefaults = UserDefaults.standard
    private let meetingsKey = "SavedMeetings"
    private var fileSystemWatcher: FileSystemWatcher?
    
    init() {
        loadMeetings()
        setupFileSystemWatcher()
    }
    
    private func setupFileSystemWatcher() {
        let audioDirectory = getAudioDirectory()
        fileSystemWatcher = FileSystemWatcher(directory: audioDirectory) { [weak self] in
            DispatchQueue.main.async {
                self?.refreshMeetings()
            }
        }
    }
    
    func refreshMeetings() {
        print("🔄 Atualizando lista de reuniões...")
        loadMeetings()
    }
    
    func saveMeeting(_ meeting: Meeting) {
        if let index = meetings.firstIndex(where: { $0.id == meeting.id }) {
            meetings[index] = meeting
        } else {
            meetings.insert(meeting, at: 0)
        }
        saveMeetings()
        
        // Notificar mudança
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        
        print("💾 Reunião salva: \(meeting.title)")
    }
    
    func deleteMeeting(_ meeting: Meeting) {
        // Deletar arquivo de áudio se existir
        if let audioPath = meeting.audioFilePath {
            do {
                try FileManager.default.removeItem(atPath: audioPath)
                print("🗑️ Arquivo de áudio deletado: \(audioPath)")
            } catch {
                print("❌ Erro ao deletar arquivo de áudio: \(error)")
            }
        }
        
        meetings.removeAll { $0.id == meeting.id }
        saveMeetings()
        
        // Notificar mudança
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        
        print("🗑️ Reunião deletada: \(meeting.title)")
    }
    
    func deleteAudioArtifacts(for meeting: Meeting) {
        var updatedMeeting = meeting
        
        // Deletar arquivo de áudio
        if let audioPath = meeting.audioFilePath {
            do {
                try FileManager.default.removeItem(atPath: audioPath)
                updatedMeeting.audioFilePath = nil
                print("🗑️ Artefatos de áudio deletados para: \(meeting.title)")
            } catch {
                print("❌ Erro ao deletar artefatos de áudio: \(error)")
            }
        }
        
        // Limpar transcrição e outros artefatos
        updatedMeeting.transcription = nil
        
        saveMeeting(updatedMeeting)
    }
    
    func updateMeetingTitle(for meetingId: UUID, newTitle: String) {
        if let index = meetings.firstIndex(where: { $0.id == meetingId }) {
            let oldTitle = meetings[index].title
            meetings[index].title = newTitle
            saveMeetings()
            
            // Notificar mudança
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
            
            print("✏️ Título atualizado: '\(oldTitle)' → '\(newTitle)'")
        }
    }
    
    func updateMeetingNotes(for meetingId: UUID, notes: String) {
        if let index = meetings.firstIndex(where: { $0.id == meetingId }) {
            meetings[index].notes = notes
            saveMeetings()
            
            // Notificar mudança (sem log para não poluir com cada keystroke)
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }
    
    func updateMeetingStatus(for meetingId: UUID, status: MeetingStatus) {
        if let index = meetings.firstIndex(where: { $0.id == meetingId }) {
            let oldStatus = meetings[index].status
            meetings[index].status = status
            saveMeetings()
            
            // Notificar mudança
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
            
            print("📊 Status atualizado: \(oldStatus.displayName) → \(status.displayName)")
        }
    }
    
    func updateMeetingDuration(for meetingId: UUID, duration: TimeInterval) {
        if let index = meetings.firstIndex(where: { $0.id == meetingId }) {
            meetings[index].duration = duration
            saveMeetings()
            
            // Notificar mudança
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
            
            print("⏱️ Duração atualizada: \(duration)s")
        }
    }
    
    func updateMeetingAudioPath(for meetingId: UUID, audioPath: String) {
        if let index = meetings.firstIndex(where: { $0.id == meetingId }) {
            meetings[index].audioFilePath = audioPath
            saveMeetings()
            
            // Notificar mudança
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
            
            print("🎵 Caminho de áudio atualizado: \(audioPath)")
        }
    }
    
    private func saveMeetings() {
        do {
            let data = try JSONEncoder().encode(meetings)
            userDefaults.set(data, forKey: meetingsKey)
            print("💾 Dados persistidos - \(meetings.count) reuniões")
        } catch {
            print("❌ Erro ao salvar reuniões: \(error)")
        }
    }
    
    private func loadMeetings() {
        guard let data = userDefaults.data(forKey: meetingsKey) else { 
            print("📂 Nenhum dado salvo encontrado")
            return 
        }
        
        do {
            let loadedMeetings = try JSONDecoder().decode([Meeting].self, from: data)
            
            // Verificar se arquivos de áudio ainda existem
            let validMeetings = loadedMeetings.compactMap { meeting -> Meeting? in
                guard let audioPath = meeting.audioFilePath else { return meeting }
                
                if FileManager.default.fileExists(atPath: audioPath) {
                    return meeting
                } else {
                    print("⚠️ Arquivo de áudio não encontrado: \(audioPath)")
                    var updatedMeeting = meeting
                    updatedMeeting.audioFilePath = nil
                    return updatedMeeting
                }
            }
            
            meetings = validMeetings
            print("📂 Reuniões carregadas: \(meetings.count)")
        } catch {
            print("❌ Erro ao carregar reuniões: \(error)")
            meetings = []
        }
    }
    
    // MARK: - Utility Methods
    
    func getRecentMeetings(limit: Int = 10) -> [Meeting] {
        return Array(meetings.prefix(limit))
    }
    
    func searchMeetings(query: String) -> [Meeting] {
        guard !query.isEmpty else { return meetings }
        
        return meetings.filter { meeting in
            meeting.title.localizedCaseInsensitiveContains(query) ||
            meeting.notes.localizedCaseInsensitiveContains(query)
        }
    }
    
    func getMeetingsByStatus(_ status: MeetingStatus) -> [Meeting] {
        return meetings.filter { $0.status == status }
    }
    
    func getTotalRecordingTime() -> TimeInterval {
        return meetings.reduce(0) { $0 + $1.duration }
    }
    
    func getMeetingsCount() -> Int {
        return meetings.count
    }
    
    // MARK: - File Management
    
    func getAudioFileSize(for meeting: Meeting) -> String {
        guard let audioPath = meeting.audioFilePath else { return "0 MB" }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: audioPath)
            if let size = attributes[.size] as? Int64 {
                return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            }
        } catch {
            print("❌ Erro ao obter tamanho do arquivo: \(error)")
        }
        
        return "0 MB"
    }
    
    func exportMeeting(_ meeting: Meeting, to url: URL) throws {
        guard let audioPath = meeting.audioFilePath else {
            throw DataManagerError.noAudioFile
        }
        
        let sourceURL = URL(fileURLWithPath: audioPath)
        try FileManager.default.copyItem(at: sourceURL, to: url)
        print("📤 Reunião exportada para: \(url.path)")
    }
    
    func cleanupOrphanedFiles() {
        let audioDirectory = getAudioDirectory()
        
        do {
            let audioFiles = try FileManager.default.contentsOfDirectory(at: audioDirectory, includingPropertiesForKeys: nil)
            let meetingAudioPaths = Set(meetings.compactMap { $0.audioFilePath })
            
            var cleanedCount = 0
            for audioFile in audioFiles {
                if !meetingAudioPaths.contains(audioFile.path) {
                    try FileManager.default.removeItem(at: audioFile)
                    cleanedCount += 1
                }
            }
            
            if cleanedCount > 0 {
                print("🧹 Arquivos órfãos removidos: \(cleanedCount)")
            }
        } catch {
            print("❌ Erro ao limpar arquivos órfãos: \(error)")
        }
    }
    
    private func getAudioDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("MeetingRecordings")
    }
}

enum DataManagerError: Error {
    case noAudioFile
    case exportFailed
    
    var localizedDescription: String {
        switch self {
        case .noAudioFile:
            return "Nenhum arquivo de áudio encontrado"
        case .exportFailed:
            return "Falha ao exportar reunião"
        }
    }
} 