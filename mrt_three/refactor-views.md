# Plano de Refatoração - Views e Gerenciamento de Estado

## 📊 Análise Atual

### Problemas Identificados

**1. Arquivo Monolítico Principal**
- `MeetingDetailView.swift`: **756 linhas** - Viola princípios SOLID
- Responsabilidades múltiplas em uma única view
- Dificulta manutenção e testes

**2. Duplicação de Código**
- Lógica de export repetida em 3 locais
- Visualização de áudio duplicada
- Padrões de seleção de meeting repetidos

**3. Problemas de Gerenciamento de Estado**
- Múltiplas fontes de verdade
- Estado manual sincronizado com `UUID()` triggers
- Views acopladas a múltiplos stores

**4. Violações de SwiftUI Best Practices**
- Criação manual de NSWindow em views
- Bodies de view muito extensos
- Hierarquias de view profundas
- Side effects em view code

## 🎯 Objetivos da Refatoração

1. **Melhorar Maintainability**: Dividir responsabilidades em componentes focados
2. **Eliminar Duplicação**: Centralizar lógica comum em services reutilizáveis
3. **Simplificar Estado**: Implementar single source of truth
4. **Seguir SwiftUI Best Practices**: Usar navegação nativa e padrões recomendados
5. **Resolver Problemas de Memória**: Gerenciamento adequado de window lifecycle

## 📋 Plano de Execução

### Fase 1: Extrair Componentes Grandes (PRIORIDADE ALTA)

#### 1.1 AudioPlayerSection
```swift
// Extrair de MeetingDetailView.swift (linhas ~416-650)
struct AudioPlayerSection: View {
    @Binding var audioPlayer: AVAudioPlayer?
    @Binding var isPlaying: Bool
    @Binding var progress: Double
    @Binding var playbackTimer: Timer?
    let meeting: Meeting
}
```

#### 1.2 TranscriptionWorkflowView  
```swift
// Extrair lógica complexa de transcrição
struct TranscriptionWorkflowView: View {
    let meeting: Meeting
    @EnvironmentObject var meetingStore: MeetingStore
    @StateObject private var transcriptionState = TranscriptionState()
}
```

#### 1.3 MeetingHeaderView
```swift
// Extrair header com edição de título
struct MeetingHeaderView: View {
    @Binding var meeting: Meeting
    @State private var editingTitle = false
    @State private var titleText = ""
}
```

### Fase 2: Consolidar Código Duplicado (PRIORIDADE ALTA)

#### 2.1 ExportService
```swift
// Centralizar toda lógica de export
@MainActor
class ExportService: ObservableObject {
    func exportAudio(meeting: Meeting) async
    func exportTranscription(result: TranscriptionResult, format: ExportFormat) async
    func exportMeeting(meeting: Meeting) async
}

enum ExportFormat {
    case text, json, clipboard
}
```

#### 2.2 AudioLevelVisualizerView
```swift
// Consolidar duplicação de visualização de áudio
struct AudioLevelVisualizerView: View {
    let level: Float
    let configuration: VisualizerConfiguration
}

struct VisualizerConfiguration {
    let barCount: Int
    let spacing: CGFloat
    let style: VisualizerStyle
}
```

#### 2.3 RecordingCoordinatorService
```swift
// Centralizar lógica de início de gravação
@MainActor
class RecordingCoordinatorService: ObservableObject {
    func startNewRecording() async -> Meeting?
    func startRecordingWorkflow() async -> Bool
}
```

### Fase 3: Refatorar Gerenciamento de Estado (PRIORIDADE MÉDIA)

#### 3.1 Simplificar MeetingStore
```swift
// Remover computed properties que delegam
// ANTES:
var isRecording: Bool { audioService?.isRecording ?? false }

// DEPOIS:
@Published var isRecording: Bool = false
// Sincronizar via Combine em vez de computed properties
```

#### 3.2 Consolidar ViewModels
```swift
// Unificar RecordingViewModel no MeetingStore
// Eliminar duplicate state management
```

#### 3.3 Implementar Single Source of Truth
```swift
// Estado centralizado para transcription workflow
@MainActor
class TranscriptionState: ObservableObject {
    @Published var currentStatus: TranscriptionStatus = .idle
    @Published var progress: Double = 0
    @Published var errorMessage: String?
}
```

### Fase 4: Corrigir Window Management (PRIORIDADE MÉDIA)

#### 4.1 WindowManager Service
```swift
@MainActor
class WindowManager: ObservableObject {
    private var transcriptionWindows: [UUID: NSWindow] = [:]
    
    func showTranscription(for meeting: Meeting, result: TranscriptionResult)
    func closeTranscription(for meeting: Meeting)
    private func createTranscriptionWindow() -> NSWindow
}
```

#### 4.2 Usar SwiftUI Navigation
```swift
// Substituir NSWindow manual por sheet/NavigationLink
.sheet(isPresented: $showingTranscription) {
    TranscriptionDetailView(result: transcriptionResult)
        .environmentObject(meetingStore)
}
```

### Fase 5: Componentes Reutilizáveis (PRIORIDADE BAIXA)

#### 5.1 Layout Components
```swift
struct CardContainer<Content: View>: View {
    let content: Content
    let style: CardStyle
}

struct SectionHeader: View {
    let title: String
    let action: (() -> Void)?
}
```

#### 5.2 Styling System
```swift
// Design tokens para consistência
extension Color {
    static let cardBackground = Color(NSColor.controlBackgroundColor)
    static let primaryAction = Color.blue
    static let destructiveAction = Color.red
}

extension Font {
    static let sectionHeader = Font.title3.weight(.semibold)
    static let metadata = Font.caption.foregroundColor(.secondary)
}
```

## 🛠 Implementação Sugerida

### Estrutura de Diretórios Proposta
```
Sources/Views/
├── Components/
│   ├── Audio/
│   │   ├── AudioPlayerSection.swift
│   │   ├── AudioLevelVisualizerView.swift
│   │   └── AudioControlsView.swift
│   ├── Meeting/
│   │   ├── MeetingHeaderView.swift
│   │   ├── MeetingMetadataView.swift
│   │   ├── MeetingNotesEditor.swift
│   │   └── MeetingActionButtons.swift
│   ├── Transcription/
│   │   ├── TranscriptionWorkflowView.swift
│   │   ├── TranscriptionSegmentView.swift
│   │   └── TranscriptionSearchBar.swift
│   ├── Export/
│   │   ├── ExportButton.swift
│   │   └── ExportOptionsSheet.swift
│   └── Layout/
│       ├── CardContainer.swift
│       └── SectionHeader.swift
├── Screens/
│   ├── MeetingDetailView.swift (refatorada)
│   ├── TranscriptionDetailView.swift 
│   └── RecordingView.swift
└── Services/
    ├── WindowManager.swift
    ├── ExportService.swift
    └── RecordingCoordinatorService.swift
```

### Estado Centralizado Proposto
```swift
// Estado principal da aplicação
@MainActor
class AppState: ObservableObject {
    @Published var meetingStore = MeetingStore()
    @Published var transcriptionState = TranscriptionState()
    @Published var recordingState = RecordingState()
    
    private let windowManager = WindowManager()
    private let exportService = ExportService()
}
```

## 🚀 Benefícios Esperados

### Técnicos
- **Redução de 50-70% no tamanho dos arquivos principais**
- **Eliminação de duplicação de código**
- **Gerenciamento de memória mais robusto**
- **Testabilidade melhorada** (componentes menores e focados)
- **Reutilização de componentes**

### UX/UI
- **Performance melhorada** (views menores e mais eficientes)
- **Consistência visual** (design system centralizado)
- **Navegação mais intuitiva** (SwiftUI navigation nativo)
- **Loading states mais fluidos** (estado centralizado)

### Manutenção
- **Desenvolvimento mais rápido** (componentes reutilizáveis)
- **Debugging simplificado** (responsabilidades claras)
- **Onboarding facilitado** (código mais legível)
- **Evolução arquitetural** (base sólida para novas features)

## ⚠️ Considerações de Migração

### Riscos
- **Quebra temporária de funcionalidades** durante migração
- **Necessidade de regressão testing extensiva**
- **Potential performance impact** durante transição

### Estratégia de Migração
1. **Branch feature dedicada** para cada fase
2. **Migração incremental** mantendo funcionalidade
3. **Testes automatizados** para cada componente extraído
4. **Rollback plan** caso problemas críticos

### Timeline Estimado
- **Fase 1**: 2-3 dias (extrair componentes grandes)
- **Fase 2**: 2-3 dias (consolidar duplicação)  
- **Fase 3**: 3-4 dias (refatorar estado)
- **Fase 4**: 2-3 dias (window management)
- **Fase 5**: 2-3 dias (componentes finais)

**Total: ~12-16 dias de desenvolvimento**

## 🔍 Próximos Passos

1. **Aprovar plano** e priorização de fases
2. **Começar com Fase 1** (maior impacto, menor risco)
3. **Extrair AudioPlayerSection** como primeira tarefa
4. **Implementar testes** para componentes extraídos
5. **Iterar e refinar** baseado em feedback

---

**Este plano resolve os problemas de memória identificados através de melhor arquitetura e gerenciamento de estado, while establishing uma base sólida para future development.**