import Foundation

/// Representa uma tarefa de transcrição na fila
struct TranscriptionTask: Identifiable, Codable {
    let id: UUID
    let meetingId: UUID
    let inputAudioPath: String
    var status: TranscriptionStatus
    var createdAt: Date
    var startedAt: Date?
    var completedAt: Date?
    var progress: Double
    var errorMessage: String?
    var outputPath: String?
    
    init(meetingId: UUID, inputAudioPath: String) {
        self.id = UUID()
        self.meetingId = meetingId
        self.inputAudioPath = inputAudioPath
        self.status = .queued
        self.createdAt = Date()
        self.progress = 0.0
    }
    
    var duration: TimeInterval? {
        guard let startedAt = startedAt else { return nil }
        let endTime = completedAt ?? Date()
        return endTime.timeIntervalSince(startedAt)
    }
    
    var isActive: Bool {
        return status == .processing || status == .queued
    }
    
    var isCompleted: Bool {
        return status == .completed || status == .failed
    }
}

/// Status de uma tarefa de transcrição
enum TranscriptionStatus: String, Codable, CaseIterable {
    case queued = "queued"
    case processing = "processing"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .queued: return "Aguardando"
        case .processing: return "Processando"
        case .completed: return "Concluído"
        case .failed: return "Falhou"
        case .cancelled: return "Cancelado"
        }
    }
    
    var color: String {
        switch self {
        case .queued: return "#007AFF"
        case .processing: return "#FF9500"
        case .completed: return "#34C759"
        case .failed: return "#FF3B30"
        case .cancelled: return "#8E8E93"
        }
    }
    
    var systemImage: String {
        switch self {
        case .queued: return "clock"
        case .processing: return "waveform"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .cancelled: return "stop.circle"
        }
    }
}

/// Resultado de uma transcrição concluída
struct TranscriptionResult: Codable {
    let taskId: UUID
    let meetingId: UUID
    let segments: [TranscriptionSegment]
    let summary: TranscriptionSummary
    let createdAt: Date
    
    struct TranscriptionSegment: Codable {
        let speakerId: Int
        let start: Double
        let end: Double
        let text: String
        let confidence: Double?
        
        var duration: Double {
            return end - start
        }
        
        var formattedTime: String {
            let startMinutes = Int(start) / 60
            let startSeconds = Int(start) % 60
            let endMinutes = Int(end) / 60
            let endSeconds = Int(end) % 60
            return String(format: "%02d:%02d-%02d:%02d", startMinutes, startSeconds, endMinutes, endSeconds)
        }
    }
    
    struct TranscriptionSummary: Codable {
        let totalDuration: Double
        let totalSpeakers: Int
        let totalWords: Int
        let confidence: Double
        
        var formattedDuration: String {
            let minutes = Int(totalDuration) / 60
            let seconds = Int(totalDuration) % 60
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    /// Converte resultado para texto formatado
    func toFormattedText() -> String {
        var result = "# Transcrição da Reunião\n\n"
        result += "**Duração:** \(summary.formattedDuration)\n"
        result += "**Número de Locutores:** \(summary.totalSpeakers)\n"
        result += "**Total de Palavras:** \(summary.totalWords)\n"
        result += "**Confiança Média:** \(String(format: "%.1f%%", summary.confidence * 100))\n\n"
        result += "---\n\n"
        
        for segment in segments {
            result += "**[\(segment.formattedTime)] Locutor \(segment.speakerId):**\n"
            result += "\(segment.text)\n\n"
        }
        
        return result
    }
    
    /// Converte resultado para JSON estruturado
    func toJSONString() -> String? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        do {
            let data = try encoder.encode(self)
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}