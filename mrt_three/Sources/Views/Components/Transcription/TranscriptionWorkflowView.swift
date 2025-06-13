import SwiftUI

// LoggingService for unified logging
private let logger = LoggingService.shared

struct TranscriptionWorkflowView: View {
    let meeting: Meeting
    @EnvironmentObject var meetingStore: MeetingStore
    @StateObject private var transcriptionState = TranscriptionState()
    
    var body: some View {
        VStack(spacing: 12) {
            headerView
            
            if meetingStore.hasTranscription(for: meeting) {
                transcriptionAvailableView
            } else {
                transcriptionStatusView
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            updateTranscriptionState()
        }
        .sheet(isPresented: $showingTranscriptionSheet) {
            if let result = transcriptionResult {
                NavigationView {
                    TranscriptionView(result: result)
                        .environmentObject(meetingStore)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Fechar") {
                                    showingTranscriptionSheet = false
                                }
                            }
                        }
                }
                .frame(minWidth: 900, minHeight: 700)
                .onAppear {
                    logger.debug("NavigationView do sheet apareceu", category: .ui)
                }
            } else {
                VStack {
                    Text("ERRO: Dados de transcrição não encontrados")
                        .foregroundColor(.red)
                        .padding()
                    
                    Button("Fechar") {
                        showingTranscriptionSheet = false
                    }
                    .padding()
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack {
            Image(systemName: "text.bubble")
                .font(.title3)
                .foregroundColor(.blue)
            
            Text("Transcrição")
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
            
            if transcriptionState.isActive {
                Image(systemName: "ellipsis")
                    .foregroundColor(.blue)
            }
        }
    }
    
    private var transcriptionAvailableView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Transcrição disponível")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
            }
            
            HStack(spacing: 12) {
                Button("Ver Transcrição") {
                    logger.debug("Ver Transcrição button tapped", category: .ui)
                    showTranscription()
                }
                .buttonStyle(.borderedProminent)
                
                // TESTE - Botão para testar com dados simulados
                Button("Ver Teste") {
                    logger.debug("Botão Ver Teste foi clicado!", category: .ui)
                    showTestTranscription()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.orange)
                
                Button("Exportar") {
                    exportTranscription()
                }
                .buttonStyle(.bordered)
                
                Button("Nova Transcrição") {
                    startNewTranscription()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var transcriptionStatusView: some View {
        switch transcriptionState.status {
        case .queued:
            transcriptionQueuedView
        case .processing:
            transcriptionProcessingView
        case .failed:
            transcriptionFailedView
        case .cancelled:
            transcriptionCancelledView
        default:
            transcriptionIdleView
        }
    }
    
    private var transcriptionIdleView: some View {
        VStack(spacing: 12) {
            Text("Nenhuma transcrição disponível")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Button("Transcrever") {
                    logger.debug("[TranscriptionWorkflow] BOTÃO TRANSCREVER CLICADO!", category: .general)
                    startNewTranscription()
                }
                .buttonStyle(.borderedProminent)
                .disabled(meetingStore.isTranscribing || meeting.audioFilePath == nil)
                .onAppear {
                    logger.debug("[TranscriptionWorkflow] Botão estado - isTranscribing: \(meetingStore.isTranscribing), audioPath: \(meeting.audioFilePath ?? "nil")", category: .general)
                    logger.debug("[TranscriptionWorkflow] audioFilePath termina com _combined.m4a: \(meeting.audioFilePath?.hasSuffix("_combined.m4a") ?? false)", category: .general)
                    logger.debug("[TranscriptionWorkflow] Botão está habilitado: \(!(meetingStore.isTranscribing || meeting.audioFilePath == nil))", category: .general)
                }
                
                // BOTÃO DE DEBUG TEMPORÁRIO
                Button("🐛 Debug Forçado") {
                    logger.debug("[DEBUG] === TESTE FORÇADO DE TRANSCRIÇÃO ===", category: .general)
                    print("[DEBUG] === TESTE FORÇADO NO CONSOLE ===")
                    
                    logger.debug("[DEBUG] Meeting ID: \(meeting.id)", category: .general)
                    logger.debug("[DEBUG] Meeting audioFilePath: \(meeting.audioFilePath ?? "nil")", category: .general)
                    logger.debug("[DEBUG] isTranscribing: \(meetingStore.isTranscribing)", category: .general)
                    
                    // Forçar chamada direta ignorando validações
                    let _ = meetingStore.startTranscription(for: meeting)
                }
                .buttonStyle(.bordered)
                .foregroundColor(.orange)
            }
        }
    }
    
    private var transcriptionQueuedView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.blue)
                Text("Aguardando na fila...")
                    .font(.subheadline)
                Spacer()
            }
            
            let queueProgress = meetingStore.transcriptionQueueProgress
            if queueProgress.total > 1 {
                Text("Posição na fila: \(queueProgress.current) de \(queueProgress.total)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button("Cancelar") {
                cancelTranscription()
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
        }
    }
    
    private var transcriptionProcessingView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "waveform")
                    .foregroundColor(.orange)
                Text("Transcrevendo...")
                    .font(.subheadline)
                Spacer()
                Text("\(Int(transcriptionState.progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: transcriptionState.progress)
                .progressViewStyle(LinearProgressViewStyle())
            
            Text("Este processo pode levar alguns minutos")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var transcriptionFailedView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                Text("Falha na transcrição")
                    .font(.subheadline)
                Spacer()
            }
            
            if let errorMessage = transcriptionState.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.leading)
            }
            
            Button("Tentar Novamente") {
                startNewTranscription()
            }
            .buttonStyle(.bordered)
        }
    }
    
    private var transcriptionCancelledView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "stop.circle")
                    .foregroundColor(.gray)
                Text("Transcrição cancelada")
                    .font(.subheadline)
                Spacer()
            }
            
            Button("Tentar Novamente") {
                startNewTranscription()
            }
            .buttonStyle(.bordered)
        }
    }
    
    // MARK: - Actions
    
    private func startNewTranscription() {
        logger.debug("[TranscriptionWorkflow] === INICIANDO NOVA TRANSCRIÇÃO ===", category: .general)
        logger.debug("[TranscriptionWorkflow] Meeting ID: \(meeting.id)", category: .general)
        logger.debug("[TranscriptionWorkflow] Audio file path: \(meeting.audioFilePath ?? "nil")", category: .general)
        
        guard meeting.audioFilePath != nil else {
            logger.error("[TranscriptionWorkflow] Não é possível transcrever: áudio não disponível", category: .general)
            return
        }
        
        let taskId = meetingStore.startTranscription(for: meeting)
        logger.debug("[TranscriptionWorkflow] Task ID retornado: \(taskId?.uuidString ?? "nil")", category: .general)
        
        updateTranscriptionState()
        logger.debug("[TranscriptionWorkflow] Estado atualizado - Status: \(transcriptionState.status?.rawValue ?? "nil")", category: .general)
    }
    
    private func cancelTranscription() {
        meetingStore.cancelTranscription(for: meeting)
        updateTranscriptionState()
    }
    
    private func showTranscription() {
        guard let result = meetingStore.getTranscriptionResult(for: meeting) else {
            logger.error("[TranscriptionWorkflow] Resultado da transcrição não encontrado", category: .general)
            return
        }
        
        // Usar sheet SwiftUI ao invés de NSWindow para evitar crashes
        showTranscriptionSheet(result: result)
        
        logger.info("[TranscriptionWorkflow] Sheet de transcrição aberto", category: .general)
    }
    
    @State private var showingTranscriptionSheet = false
    @State private var transcriptionResult: TranscriptionResult?
    
    private func showTranscriptionSheet(result: TranscriptionResult) {
        logger.debug("Abrindo sheet com resultado - TaskID: \(result.taskId), Segments: \(result.segments.count)", category: .ui)
        
        transcriptionResult = result
        showingTranscriptionSheet = true
        
        logger.debug("Sheet state updated - showing: \(showingTranscriptionSheet), result nil: \(transcriptionResult == nil)", category: .ui)
    }
    
    private func showTestTranscription() {
        logger.debug("Criando dados de teste para transcrição", category: .ui)
        
        let testResult = TranscriptionResult(
            taskId: UUID(),
            meetingId: meeting.id,
            segments: [
                TranscriptionResult.TranscriptionSegment(
                    speakerId: 1,
                    start: 0.0,
                    end: 15.5,
                    text: "Olá, bem-vindos à nossa reunião de hoje. Vamos começar discutindo os principais pontos da agenda para esta semana.",
                    confidence: 0.95
                ),
                TranscriptionResult.TranscriptionSegment(
                    speakerId: 2,
                    start: 16.0,
                    end: 32.3,
                    text: "Perfeito! Acredito que devemos focar primeiro nos resultados do último trimestre antes de avançar para os novos projetos em desenvolvimento.",
                    confidence: 0.92
                ),
                TranscriptionResult.TranscriptionSegment(
                    speakerId: 1,
                    start: 33.0,
                    end: 45.8,
                    text: "Concordo completamente. Os números mostram uma tendência positiva e isso nos dá uma base sólida para o planejamento futuro.",
                    confidence: 0.88
                )
            ],
            summary: TranscriptionResult.TranscriptionSummary(
                totalDuration: 45.8,
                totalSpeakers: 2,
                totalWords: 62,
                confidence: 0.92
            ),
            createdAt: Date()
        )
        
        showTranscriptionSheet(result: testResult)
    }
    
    private func exportTranscription() {
        guard let result = meetingStore.getTranscriptionResult(for: meeting) else {
            logger.error("[TranscriptionWorkflow] Resultado da transcrição não encontrado para export", category: .general)
            return
        }
        
        Task {
            await ExportService.shared.exportTranscription(
                result: result,
                format: .text,
                filename: "\(meeting.title)_transcricao"
            )
        }
    }
    
    private func updateTranscriptionState() {
        transcriptionState.status = meetingStore.getTranscriptionStatus(for: meeting)
        transcriptionState.progress = meetingStore.getTranscriptionProgress(for: meeting)
        
        // Buscar erro se houver
        if let taskId = meeting.transcriptionTaskId,
           let task = meetingStore.transcriptionTasks.first(where: { $0.id == taskId }) {
            transcriptionState.errorMessage = task.errorMessage
        }
    }
}

// MARK: - Supporting State Object

@MainActor
class TranscriptionState: ObservableObject {
    @Published var status: TranscriptionStatus? = nil
    @Published var progress: Double = 0
    @Published var errorMessage: String?
    
    var isActive: Bool {
        guard let status = status else { return false }
        switch status {
        case .queued, .processing:
            return true
        default:
            return false
        }
    }
}

#Preview {
    TranscriptionWorkflowView(meeting: Meeting())
        .environmentObject(MeetingStore())
        .frame(width: 400)
        .padding()
}