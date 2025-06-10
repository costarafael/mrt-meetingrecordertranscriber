import Foundation
import OSLog

/// Service unificado de logging para substituir print() statements
final class LoggingService {
    static let shared = LoggingService()
    
    private let logger: Logger
    
    private init() {
        self.logger = Logger(subsystem: "com.meetingrecorder.macos", category: "Application")
    }
    
    // MARK: - Public Logging Methods
    
    func debug(_ message: String, category: LogCategory = .general) {
        logger.debug("[\(category.rawValue)] \(message)")
    }
    
    func info(_ message: String, category: LogCategory = .general) {
        logger.info("[\(category.rawValue)] \(message)")
    }
    
    func warning(_ message: String, category: LogCategory = .general) {
        logger.warning("[\(category.rawValue)] ⚠️ \(message)")
    }
    
    func error(_ message: String, error: Error? = nil, category: LogCategory = .general) {
        if let error = error {
            logger.error("[\(category.rawValue)] ❌ \(message): \(error.localizedDescription)")
        } else {
            logger.error("[\(category.rawValue)] ❌ \(message)")
        }
    }
    
    func critical(_ message: String, error: Error? = nil, category: LogCategory = .general) {
        if let error = error {
            logger.critical("[\(category.rawValue)] 💥 CRITICAL: \(message): \(error.localizedDescription)")
        } else {
            logger.critical("[\(category.rawValue)] 💥 CRITICAL: \(message)")
        }
    }
    
    // MARK: - Specialized Logging Methods
    
    func audioEvent(_ message: String, details: [String: Any] = [:]) {
        var logMessage = "🎵 \(message)"
        if !details.isEmpty {
            let detailsString = details.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            logMessage += " | \(detailsString)"
        }
        logger.info("[\(LogCategory.audio.rawValue)] \(logMessage)")
    }
    
    func recordingEvent(_ message: String, meetingId: UUID? = nil) {
        var logMessage = "🎙️ \(message)"
        if let id = meetingId {
            logMessage += " | Meeting: \(id.uuidString.prefix(8))"
        }
        logger.info("[\(LogCategory.recording.rawValue)] \(logMessage)")
    }
    
    func fileOperation(_ message: String, path: String? = nil) {
        var logMessage = "📁 \(message)"
        if let path = path {
            logMessage += " | Path: \(path)"
        }
        logger.info("[\(LogCategory.file.rawValue)] \(logMessage)")
    }
    
    func uiEvent(_ message: String) {
        logger.debug("[\(LogCategory.ui.rawValue)] 🖥️ \(message)")
    }
    
    func performance(_ message: String, duration: TimeInterval? = nil) {
        var logMessage = "⚡ \(message)"
        if let duration = duration {
            logMessage += " | Duration: \(String(format: "%.3f", duration))s"
        }
        logger.info("[\(LogCategory.performance.rawValue)] \(logMessage)")
    }
}

// MARK: - Log Categories

enum LogCategory: String, CaseIterable {
    case general = "General"
    case audio = "Audio"
    case recording = "Recording"
    case file = "File"
    case ui = "UI"
    case network = "Network"
    case performance = "Performance"
    case diagnostics = "Diagnostics"
}

// MARK: - Convenience Extensions

extension LoggingService {
    /// Log início de operação com timing automático
    func startOperation(_ operation: String, category: LogCategory = .general) -> OperationTimer {
        info("Starting: \(operation)", category: category)
        return OperationTimer(operation: operation, category: category, logger: self)
    }
}

// MARK: - Operation Timer

final class OperationTimer {
    private let operation: String
    private let category: LogCategory
    private let logger: LoggingService
    private let startTime: Date
    
    init(operation: String, category: LogCategory, logger: LoggingService) {
        self.operation = operation
        self.category = category
        self.logger = logger
        self.startTime = Date()
    }
    
    func finish(success: Bool = true) {
        let duration = Date().timeIntervalSince(startTime)
        let status = success ? "✅ Completed" : "❌ Failed"
        logger.performance("\(status): \(operation)", duration: duration)
    }
} 