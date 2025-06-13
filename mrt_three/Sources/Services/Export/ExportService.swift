import Foundation
import SwiftUI
import UniformTypeIdentifiers

// LoggingService for unified logging
private let logger = LoggingService.shared

@MainActor
class ExportService: ObservableObject {
    static let shared = ExportService()
    
    private init() {}
    
    // MARK: - Export Types
    
    enum ExportFormat {
        case text
        case json
        case clipboard
        case audio
        
        var fileExtension: String {
            switch self {
            case .text: return "txt"
            case .json: return "json"
            case .audio: return "m4a"
            case .clipboard: return "" // N/A for clipboard
            }
        }
        
        var contentType: UTType {
            switch self {
            case .text: return .plainText
            case .json: return .json
            case .audio: return .audio
            case .clipboard: return .plainText
            }
        }
    }
    
    enum ExportError: Error, LocalizedError {
        case noContent
        case invalidFormat
        case fileWriteError(Error)
        case clipboardError
        
        var errorDescription: String? {
            switch self {
            case .noContent:
                return "Nenhum conteúdo disponível para exportar"
            case .invalidFormat:
                return "Formato de export inválido"
            case .fileWriteError(let error):
                return "Erro ao salvar arquivo: \(error.localizedDescription)"
            case .clipboardError:
                return "Erro ao copiar para área de transferência"
            }
        }
    }
    
    // MARK: - Audio Export
    
    /// Exportar áudio de uma reunião
    /// - Parameters:
    ///   - meeting: Reunião para exportar
    ///   - meetingStore: Store para operações de meeting
    /// - Returns: Success indicator
    func exportAudio(meeting: Meeting, using meetingStore: MeetingStore) async -> Bool {
        guard meeting.audioFilePath != nil else {
            logger.error("[ExportService] Reunião não possui arquivo de áudio para exportar", category: .general)
            return false
        }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.audio]
        panel.nameFieldStringValue = "\(meeting.title).m4a"
        panel.title = "Exportar Áudio da Reunião"
        panel.message = "Escolha onde salvar o arquivo de áudio"
        
        guard panel.runModal() == .OK, let url = panel.url else {
            logger.debug("Export de áudio cancelado pelo usuário", category: .general)
            return false
        }
        
        do {
            try meetingStore.exportMeeting(meeting, to: url)
            logger.info("[ExportService] Áudio exportado com sucesso: \(url.path)", category: .general)
            return true
        } catch {
            logger.error("[ExportService] Erro ao exportar áudio: \(error)", category: .general)
            return false
        }
    }
    
    // MARK: - Transcription Export
    
    /// Exportar transcrição em formato específico
    /// - Parameters:
    ///   - result: Resultado da transcrição
    ///   - format: Formato desejado
    ///   - filename: Nome base do arquivo (sem extensão)
    /// - Returns: Success indicator
    func exportTranscription(
        result: TranscriptionResult,
        format: ExportFormat,
        filename: String
    ) async -> Bool {
        switch format {
        case .clipboard:
            return copyTranscriptionToClipboard(result: result)
        case .text, .json:
            return await exportTranscriptionToFile(
                result: result,
                format: format,
                filename: filename
            )
        case .audio:
            logger.error("[ExportService] Formato de áudio não suportado para transcrição", category: .general)
            return false
        }
    }
    
    /// Exportar transcrição para arquivo
    private func exportTranscriptionToFile(
        result: TranscriptionResult,
        format: ExportFormat,
        filename: String
    ) async -> Bool {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format.contentType]
        panel.nameFieldStringValue = "\(filename).\(format.fileExtension)"
        panel.title = "Exportar Transcrição"
        panel.message = "Escolha onde salvar a transcrição"
        
        guard panel.runModal() == .OK, let url = panel.url else {
            logger.debug("Export de transcrição cancelado pelo usuário", category: .general)
            return false
        }
        
        do {
            let content = try generateTranscriptionContent(result: result, format: format)
            try content.write(to: url, atomically: true, encoding: .utf8)
            logger.info("[ExportService] Transcrição exportada: \(url.path)", category: .general)
            return true
        } catch {
            logger.error("[ExportService] Erro ao exportar transcrição: \(error)", category: .general)
            return false
        }
    }
    
    /// Copiar transcrição para área de transferência
    private func copyTranscriptionToClipboard(result: TranscriptionResult) -> Bool {
        do {
            let content = try generateTranscriptionContent(result: result, format: .text)
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            let success = pasteboard.setString(content, forType: .string)
            
            if success {
                logger.info("[ExportService] Transcrição copiada para área de transferência", category: .general)
                return true
            } else {
                logger.error("[ExportService] Falha ao copiar para área de transferência", category: .general)
                return false
            }
        } catch {
            logger.error("[ExportService] Erro ao gerar conteúdo para clipboard: \(error)", category: .general)
            return false
        }
    }
    
    /// Gerar conteúdo da transcrição no formato especificado
    private func generateTranscriptionContent(
        result: TranscriptionResult,
        format: ExportFormat
    ) throws -> String {
        switch format {
        case .text, .clipboard:
            return result.toFormattedText()
        case .json:
            guard let jsonString = result.toJSONString() else {
                throw ExportError.invalidFormat
            }
            return jsonString
        case .audio:
            throw ExportError.invalidFormat
        }
    }
    
    // MARK: - Meeting Export (Complete)
    
    /// Exportar reunião completa (áudio + transcrição se disponível)
    /// - Parameters:
    ///   - meeting: Reunião para exportar
    ///   - meetingStore: Store para operações
    ///   - includeTranscription: Se deve incluir transcrição
    /// - Returns: Success indicator
    func exportMeetingComplete(
        meeting: Meeting,
        using meetingStore: MeetingStore,
        includeTranscription: Bool = true
    ) async -> Bool {
        logger.debug("Iniciando export completo da reunião: \(meeting.title)", category: .general)
        
        var success = true
        
        // Exportar áudio se disponível
        if meeting.audioFilePath != nil {
            success = await exportAudio(meeting: meeting, using: meetingStore)
        }
        
        // Exportar transcrição se disponível e solicitado
        if includeTranscription,
           let transcriptionResult = meetingStore.getTranscriptionResult(for: meeting) {
            let transcriptionSuccess = await exportTranscription(
                result: transcriptionResult,
                format: .text,
                filename: "\(meeting.title)_transcricao"
            )
            success = success && transcriptionSuccess
        }
        
        return success
    }
    
    // MARK: - Convenience Methods
    
    /// Show export options for transcription
    /// - Parameters:
    ///   - result: Transcription result
    ///   - filename: Base filename
    ///   - completion: Completion handler
    func showTranscriptionExportOptions(
        result: TranscriptionResult,
        filename: String,
        completion: @escaping (Bool) -> Void
    ) {
        Task {
            // For now, default to text format
            // Could be extended to show a picker dialog
            let success = await exportTranscription(
                result: result,
                format: .text,
                filename: filename
            )
            completion(success)
        }
    }
    
    /// Quick clipboard copy for transcription
    /// - Parameter result: Transcription result
    /// - Returns: Success indicator
    func quickCopyTranscription(result: TranscriptionResult) -> Bool {
        return copyTranscriptionToClipboard(result: result)
    }
}

// MARK: - Export Configuration

struct ExportConfiguration {
    let defaultAudioFormat: UTType = .audio
    let defaultTextFormat: UTType = .plainText
    let compressionQuality: Float = 0.8
    let includeMetadata: Bool = true
    
    static let `default` = ExportConfiguration()
}

