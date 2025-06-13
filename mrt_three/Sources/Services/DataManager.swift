import Foundation
import Combine

// LoggingService for unified logging
private let logger = LoggingService.shared

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
        logger.debug("🔄 Atualizando lista de reuniões...", category: .general)
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
        
        logger.debug("💾 Reunião salva: \(meeting.title)", category: .general)
    }
    
    func deleteMeeting(_ meeting: Meeting) {
        // Deletar arquivo de áudio se existir
        if let audioPath = meeting.audioFilePath {
            do {
                try FileManager.default.removeItem(atPath: audioPath)
                logger.debug("🗑️ Arquivo de áudio deletado: \(audioPath)", category: .general)
            } catch {
                logger.error("Erro ao deletar arquivo de áudio: \(error)", category: .general)
            }
        }
        
        meetings.removeAll { $0.id == meeting.id }
        saveMeetings()
        
        // Notificar mudança
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        
        logger.debug("🗑️ Reunião deletada: \(meeting.title)", category: .general)
    }
    
    func deleteAudioArtifacts(for meeting: Meeting) {
        var updatedMeeting = meeting
        
        // Deletar arquivo de áudio
        if let audioPath = meeting.audioFilePath {
            do {
                try FileManager.default.removeItem(atPath: audioPath)
                updatedMeeting.audioFilePath = nil
                logger.debug("🗑️ Artefatos de áudio deletados para: \(meeting.title)", category: .general)
            } catch {
                logger.error("Erro ao deletar artefatos de áudio: \(error)", category: .general)
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
            
            logger.debug("✏️ Título atualizado: '\(oldTitle)' → '\(newTitle)'", category: .general)
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
            
            logger.debug("Status atualizado: \(oldStatus.displayName) → \(status.displayName)", category: .performance)
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
            
            logger.debug("⏱️ Duração atualizada: \(duration)s", category: .general)
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
            
            logger.debug("🎵 Caminho de áudio atualizado: \(audioPath)", category: .general)
        }
    }
    
    private func saveMeetings() {
        do {
            let data = try JSONEncoder().encode(meetings)
            userDefaults.set(data, forKey: meetingsKey)
            logger.debug("💾 Dados persistidos - \(meetings.count) reuniões", category: .general)
        } catch {
            logger.error("Erro ao salvar reuniões: \(error)", category: .general)
        }
    }
    
    private func loadMeetings() {
        guard let data = userDefaults.data(forKey: meetingsKey) else { 
            logger.debug("📂 Nenhum dado salvo encontrado", category: .general)
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
                    logger.warning("Arquivo de áudio não encontrado: \(audioPath)", category: .general)
                    var updatedMeeting = meeting
                    updatedMeeting.audioFilePath = nil
                    return updatedMeeting
                }
            }
            
            meetings = validMeetings
            logger.debug("📂 Reuniões carregadas: \(meetings.count)", category: .general)
        } catch {
            logger.error("Erro ao carregar reuniões: \(error)", category: .general)
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
            logger.error("Erro ao obter tamanho do arquivo: \(error)", category: .general)
        }
        
        return "0 MB"
    }
    
    func exportMeeting(_ meeting: Meeting, to url: URL) throws {
        guard let audioPath = meeting.audioFilePath else {
            throw DataManagerError.noAudioFile
        }
        
        let sourceURL = URL(fileURLWithPath: audioPath)
        try FileManager.default.copyItem(at: sourceURL, to: url)
        logger.debug("📤 Reunião exportada para: \(url.path)", category: .general)
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
                logger.debug("🧹 Arquivos órfãos removidos: \(cleanedCount)", category: .general)
            }
        } catch {
            logger.error("Erro ao limpar arquivos órfãos: \(error)", category: .general)
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