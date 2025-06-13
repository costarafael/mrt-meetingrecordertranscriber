import Foundation

struct Meeting: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    let createdAt: Date
    var duration: TimeInterval
    var status: MeetingStatus
    var audioFilePath: String?
    var notes: String
    var participants: [String] // Para futuro uso
    var transcription: String? // Para futuro uso
    var transcriptionTaskId: UUID? // ID da tarefa de transcrição
    var hasTranscription: Bool? // Indica se possui transcrição completa
    
    init(title: String? = nil) {
        let now = Date()
        self.id = UUID()
        self.title = title ?? "Reunião \(DateFormatter.meetingTitle.string(from: now))"
        self.createdAt = now
        self.duration = 0
        self.status = .ready
        self.notes = ""
        self.participants = []
        self.transcription = nil
        self.audioFilePath = nil
    }
    
    var formattedDuration: String {
        return TimeInterval.formatDuration(duration)
    }
    
    var formattedDate: String {
        DateFormatter.meetingDate.string(from: createdAt)
    }
    
    var transcriptionAvailable: Bool {
        return hasTranscription ?? false
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Meeting, rhs: Meeting) -> Bool {
        return lhs.id == rhs.id
    }
}

enum MeetingStatus: String, Codable, CaseIterable {
    case ready = "ready"
    case recording = "recording"
    case paused = "paused"
    case completed = "completed"
    
    var displayName: String {
        switch self {
        case .ready: return "Pronta"
        case .recording: return "Gravando"
        case .paused: return "Pausada"
        case .completed: return "Concluída"
        }
    }
    
    var color: String {
        switch self {
        case .ready: return "#007AFF"
        case .recording: return "#FF3B30"
        case .paused: return "#FF9500"
        case .completed: return "#34C759"
        }
    }
}

extension DateFormatter {
    static let meetingTitle: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter
    }()
    
    static let meetingDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()
    
    static let meetingTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
} 