# Guia de Estilo - Meeting Recorder macOS

## 📋 Convenções de Nomenclatura

### 🔤 **Idioma**
- **Código (classes, métodos, variáveis)**: **Inglês**
- **Strings de UI**: **Português** (interface do usuário)
- **Comentários**: **Português** (para facilitar manutenção da equipe)
- **Logs**: **Inglês** (para debugging e análise técnica)

### 🏗️ **Estrutura de Arquivos**

```
Sources/
├── App/                    # Entrada da aplicação
├── Views/
│   ├── Components/         # Componentes reutilizáveis
│   └── [FeatureViews].swift
├── ViewModels/             # Lógica de apresentação
├── Models/                 # Modelos de dados
├── Services/               # Lógica de negócio
│   ├── Audio/             # Services de áudio específicos
│   ├── Logging/           # Sistema de logging
│   ├── Diagnostics/       # Diagnósticos e monitoramento
│   └── [Feature]/         # Services por funcionalidade
└── Core/                  # Componentes centrais
    ├── Extensions/        # Extensões utilitárias
    ├── Audio/            # Protocolos e modelos de áudio
    └── [Shared]/         # Código compartilhado
```

### 🎯 **Nomenclatura de Classes e Structs**

#### **Services**
```swift
// ✅ Correto
class AudioFileService { }
class LoggingService { }
class DiagnosticsService { }

// ❌ Evitar
class AudioFileManager { }  // Use "Service" para lógica de negócio
class Logger { }            // Use "Service" para consistência
```

#### **Views**
```swift
// ✅ Correto
struct MeetingDetailView: View { }
struct AudioSettingsView: View { }
struct StatusBadge: View { }

// ❌ Evitar
struct MeetingDetail { }    // Sempre incluir "View"
struct Settings { }         // Seja específico
```

#### **ViewModels**
```swift
// ✅ Correto
class MeetingStore: ObservableObject { }
class AudioRecordingCoordinator: ObservableObject { }

// ❌ Evitar
class MeetingViewModel { }  // Use "Store" para dados
class AudioManager { }      // Use "Coordinator" para orquestração
```

### 🔧 **Nomenclatura de Métodos**

#### **Padrões de Verbos**
```swift
// ✅ Ações
func startRecording()
func stopRecording()
func pauseRecording()
func resumeRecording()

// ✅ Configuração
func setupAudioFiles()
func configureEngine()
func initializeService()

// ✅ Validação
func validatePermissions()
func checkAudioFormat()
func verifyFileIntegrity()

// ✅ Obtenção de dados
func getAudioDevices()
func loadMeetings()
func fetchConfiguration()

// ✅ Processamento
func processAudioBuffer()
func convertFormat()
func combineAudioFiles()
```

#### **Padrões de Nomenclatura**
```swift
// ✅ Específico e claro
func trackMicrophoneBuffer(_ buffer: AVAudioPCMBuffer)
func validateAudioFormats(fileFormat: AVAudioFormat, bufferFormat: AVAudioFormat)
func monitorPerformance<T>(operation: String, _ block: () throws -> T)

// ❌ Genérico demais
func track(_ buffer: AVAudioPCMBuffer)
func validate(_ format1: AVAudioFormat, _ format2: AVAudioFormat)
func monitor<T>(_ block: () throws -> T)
```

### 📝 **Strings de Interface**

#### **Títulos e Labels**
```swift
// ✅ Português para UI
Text("Configurações de Áudio")
Text("Dispositivo de Entrada")
Text("Gravando Reunião")
Text("Reuniões Recentes")

// ✅ Mensagens de erro para usuário
"Permissões de áudio negadas"
"Erro ao iniciar gravação"
"Arquivo não encontrado"
```

#### **Logs e Debug**
```swift
// ✅ Inglês para logs técnicos
logger.info("Recording started successfully")
logger.error("Failed to initialize audio engine")
logger.debug("Buffer validation completed")

// ✅ Categorias em inglês
.recording, .audio, .file, .performance, .diagnostics
```

### 🏷️ **Convenções de Variáveis**

#### **Propriedades Published**
```swift
// ✅ Estado da aplicação
@Published var isRecording = false
@Published var currentDuration: TimeInterval = 0
@Published var availableDevices: [AudioDevice] = []
@Published var selectedDevice: AudioDevice?
```

#### **Propriedades Privadas**
```swift
// ✅ Services e dependências
private let audioFileService: AudioFileService
private let diagnostics = DiagnosticsService()
private let logger = LoggingService.shared

// ✅ Estado interno
private var currentConfiguration: AudioConfiguration?
private var recordingStartTime: Date?
```

### 🎨 **Padrões de Código**

#### **Organização de Métodos**
```swift
class ExampleService {
    // MARK: - Public Methods
    func publicMethod() { }
    
    // MARK: - Configuration
    func setupMethod() { }
    
    // MARK: - Private Helpers
    private func privateMethod() { }
    
    // MARK: - Event Handlers
    private func handleEvent() { }
}
```

#### **Error Handling**
```swift
// ✅ Logging estruturado
do {
    try performOperation()
    logger.info("Operation completed successfully")
} catch {
    logger.error("Operation failed", error: error, category: .audio)
    throw AudioServiceError.operationFailed(error)
}
```

#### **Async/Await**
```swift
// ✅ Métodos async bem nomeados
func startAudioCapture(configuration: AudioConfiguration) async throws
func requestPermissions() async -> Bool
func processRecordingFiles() async -> String?
```

### 📊 **Logging e Diagnósticos**

#### **Categorias de Log**
```swift
enum LogCategory: String {
    case general = "General"
    case audio = "Audio"
    case recording = "Recording"
    case file = "File"
    case ui = "UI"
    case performance = "Performance"
    case diagnostics = "Diagnostics"
}
```

#### **Níveis de Log**
```swift
// ✅ Debug: Informações detalhadas para desenvolvimento
logger.debug("Setting up audio engine", category: .audio)

// ✅ Info: Eventos importantes do sistema
logger.info("Recording started", category: .recording)

// ✅ Warning: Situações que merecem atenção
logger.warning("Audio format mismatch detected", category: .diagnostics)

// ✅ Error: Erros recuperáveis
logger.error("Failed to write audio buffer", error: error, category: .file)

// ✅ Critical: Erros críticos do sistema
logger.critical("Audio engine initialization failed", error: error, category: .audio)
```

### 🔄 **Padrões de Refatoração**

#### **Single Responsibility**
```swift
// ✅ Uma responsabilidade por classe
class AudioFileService {
    // Apenas gerenciamento de arquivos de áudio
}

class DiagnosticsService {
    // Apenas diagnósticos e monitoramento
}

class LoggingService {
    // Apenas logging estruturado
}
```

#### **Dependency Injection**
```swift
// ✅ Injeção clara de dependências
init(
    audioFileManager: AudioFileManagerProtocol,
    permissionManager: AudioPermissionManager,
    logger: LoggingService = .shared
) {
    self.audioFileManager = audioFileManager
    self.permissionManager = permissionManager
    self.logger = logger
}
```

### ✅ **Checklist de Qualidade**

Antes de fazer commit, verificar:

- [ ] Nomenclatura em inglês para código
- [ ] Strings de UI em português
- [ ] Logs em inglês com categorias apropriadas
- [ ] Métodos com responsabilidade única
- [ ] Error handling adequado
- [ ] Documentação de métodos públicos
- [ ] Testes para lógica crítica
- [ ] Performance adequada
- [ ] Memory leaks verificados

### 🎯 **Exemplos de Refatoração**

#### **Antes (Inconsistente)**
```swift
// ❌ Mistura de idiomas e responsabilidades
class AudioManager {
    func iniciarGravacao() {
        print("🎯 Iniciando gravação...")
        // 50+ linhas de código
    }
}
```

#### **Depois (Consistente)**
```swift
// ✅ Inglês, responsabilidade única, logging estruturado
class AudioRecordingCoordinator {
    func startRecording(for meeting: Meeting) async -> Bool {
        logger.recordingEvent("Starting recording", meetingId: meeting.id)
        // Lógica simplificada usando services especializados
    }
}
```

---

**Objetivo:** Manter código limpo, consistente e facilmente manutenível seguindo princípios SOLID e boas práticas de Swift/SwiftUI. 