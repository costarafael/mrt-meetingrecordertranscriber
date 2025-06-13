import SwiftUI

struct TranscriptionView: View {
    let result: TranscriptionResult
    @EnvironmentObject var meetingStore: MeetingStore
    @State private var searchText = ""
    @State private var selectedSpeaker: Int? = nil
    @State private var showingExportOptions = false
    
    private let logger = LoggingService.shared
    
    private var filteredSegments: [TranscriptionResult.TranscriptionSegment] {
        let segments = result.segments
        
        // Filter by speaker if selected
        let speakerFiltered = selectedSpeaker == nil ? segments : segments.filter { $0.speakerId == selectedSpeaker }
        
        // Filter by search text
        if searchText.isEmpty {
            return speakerFiltered
        } else {
            return speakerFiltered.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    private var uniqueSpeakers: [Int] {
        Array(Set(result.segments.map { $0.speakerId })).sorted()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            controlsView
            Divider()
            transcriptionContent
        }
        .navigationTitle("Transcrição")
        .sheet(isPresented: $showingExportOptions) {
            exportOptionsView
        }
        .onAppear {
            logger.debug("TranscriptionView appeared - Segments: \(result.segments.count), Words: \(result.summary.totalWords)", category: .ui)
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Resumo da Transcrição")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                
                Button("Exportar") {
                    showingExportOptions = true
                }
                .buttonStyle(.borderedProminent)
            }
            
            HStack(spacing: 24) {
                summaryItem(title: "Duração", value: result.summary.formattedDuration, icon: "clock")
                summaryItem(title: "Locutores", value: "\(result.summary.totalSpeakers)", icon: "person.2")
                summaryItem(title: "Palavras", value: "\(result.summary.totalWords)", icon: "text.alignleft")
                summaryItem(title: "Confiança", value: "\(Int(result.summary.confidence * 100))%", icon: "checkmark.seal")
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private func summaryItem(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
            Text(value)
                .font(.headline)
                .fontWeight(.medium)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var controlsView: some View {
        HStack(spacing: 16) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Buscar na transcrição...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button("Limpar") {
                        searchText = ""
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                }
            }
            .padding(8)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)
            
            // Speaker filter
            Picker("Locutor", selection: $selectedSpeaker) {
                Text("Todos os locutores").tag(nil as Int?)
                ForEach(uniqueSpeakers, id: \.self) { speaker in
                    Text("Locutor \(speaker)").tag(speaker as Int?)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 160)
        }
        .padding()
    }
    
    private var transcriptionContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if filteredSegments.isEmpty {
                    emptyStateView
                } else {
                    ForEach(Array(filteredSegments.enumerated()), id: \.element.start) { index, segment in
                        transcriptionSegmentView(segment: segment, index: index)
                    }
                }
            }
            .padding()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("Nenhum resultado encontrado")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Tente ajustar os filtros de busca ou locutor")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    private func transcriptionSegmentView(segment: TranscriptionResult.TranscriptionSegment, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with speaker and time
            HStack {
                speakerBadge(speakerId: segment.speakerId)
                
                Spacer()
                
                Text(segment.formattedTime)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(4)
            }
            
            // Transcription text
            SelectableText(segment.text)
                .font(.body)
                .lineSpacing(2)
                .textSelection(.enabled)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func speakerBadge(speakerId: Int) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(speakerColor(for: speakerId))
                .frame(width: 12, height: 12)
            
            Text("Locutor \(speakerId)")
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(speakerColor(for: speakerId).opacity(0.1))
        .cornerRadius(20)
    }
    
    private func speakerColor(for speakerId: Int) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .red, .pink]
        return colors[speakerId % colors.count]
    }
    
    private var exportOptionsView: some View {
        VStack(spacing: 20) {
            Text("Exportar Transcrição")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                exportButton(
                    title: "Texto Formatado (.txt)",
                    description: "Formato legível para leitura",
                    icon: "doc.text",
                    action: { exportAsText() }
                )
                
                exportButton(
                    title: "JSON Estruturado (.json)",
                    description: "Formato estruturado para processamento",
                    icon: "doc.text.below.ecg",
                    action: { exportAsJSON() }
                )
                
                exportButton(
                    title: "Copiar para Área de Transferência",
                    description: "Copiar texto formatado",
                    icon: "doc.on.clipboard",
                    action: { copyToClipboard() }
                )
            }
            
            Button("Cancelar") {
                showingExportOptions = false
            }
            .buttonStyle(.bordered)
        }
        .padding(24)
        .frame(width: 400)
    }
    
    private func exportButton(title: String, description: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Export Methods
    
    private func exportAsText() {
        Task {
            let success = await ExportService.shared.exportTranscription(
                result: result,
                format: .text,
                filename: "transcricao"
            )
            if success {
                showingExportOptions = false
            }
        }
    }
    
    private func exportAsJSON() {
        Task {
            let success = await ExportService.shared.exportTranscription(
                result: result,
                format: .json,
                filename: "transcricao"
            )
            if success {
                showingExportOptions = false
            }
        }
    }
    
    private func copyToClipboard() {
        let success = ExportService.shared.quickCopyTranscription(result: result)
        if success {
            showingExportOptions = false
        }
    }
}

// Helper view for selectable text with improved memory management
struct SelectableText: NSViewRepresentable {
    let text: String
    
    init(_ text: String) {
        self.text = text
    }
    
    func makeNSView(context: Context) -> SafeTextView {
        let textView = SafeTextView()
        textView.setupInitialConfiguration()
        textView.string = text
        return textView
    }
    
    func updateNSView(_ nsView: SafeTextView, context: Context) {
        // Só atualizar se o texto realmente mudou
        if nsView.string != text {
            nsView.string = text
        }
    }
    
    static func dismantleNSView(_ nsView: SafeTextView, coordinator: ()) {
        nsView.performCleanup()
    }
}

// MARK: - Safe Text View

final class SafeTextView: NSTextView {
    private var hasBeenConfigured = false
    
    func setupInitialConfiguration() {
        guard !hasBeenConfigured else { return }
        hasBeenConfigured = true
        
        isEditable = false
        isSelectable = true
        backgroundColor = .clear
        textContainer?.lineFragmentPadding = 0
        textContainerInset = .zero
        
        // Configurações adicionais para performance
        isVerticallyResizable = true
        isHorizontallyResizable = false
        textContainer?.widthTracksTextView = true
        textContainer?.containerSize = NSSize(width: frame.width, height: CGFloat.greatestFiniteMagnitude)
    }
    
    func performCleanup() {
        // Cleanup sistemático
        delegate = nil
        
        // Limpar texto
        string = ""
        
        // Limpar layout manager e text container
        if let layoutManager = layoutManager {
            textStorage?.removeLayoutManager(layoutManager)
            
            // Remover text containers
            while layoutManager.textContainers.count > 0 {
                layoutManager.removeTextContainer(at: 0)
            }
        }
        
        // Limpar text storage
        textStorage?.delegate = nil
        
        // Remover da superview
        removeFromSuperview()
    }
    
    deinit {
        performCleanup()
    }
}

#Preview {
    let sampleResult = TranscriptionResult(
        taskId: UUID(),
        meetingId: UUID(),
        segments: [
            TranscriptionResult.TranscriptionSegment(
                speakerId: 1,
                start: 0.0,
                end: 10.5,
                text: "Olá, bem-vindos à nossa reunião de hoje. Vamos começar discutindo os principais pontos da agenda.",
                confidence: 0.95
            ),
            TranscriptionResult.TranscriptionSegment(
                speakerId: 2,
                start: 11.0,
                end: 25.3,
                text: "Perfeito. Acredito que devemos focar primeiro nos resultados do último trimestre antes de avançar para os novos projetos.",
                confidence: 0.92
            )
        ],
        summary: TranscriptionResult.TranscriptionSummary(
            totalDuration: 125.0,
            totalSpeakers: 2,
            totalWords: 45,
            confidence: 0.93
        ),
        createdAt: Date()
    )
    
    return TranscriptionView(result: sampleResult)
}