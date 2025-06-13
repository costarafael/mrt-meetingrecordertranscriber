# 🚀 Guia de Instalação - Backend SherpaONNX

## ✅ **Verificação Rápida**

Execute o teste automático para verificar se tudo está funcionando:

```bash
cd pipeline_swift
./test-pipeline.sh
```

Se todos os testes passarem, você pode usar o backend imediatamente!

## 🎯 **Uso Básico**

### **1. Transcrição com modelo Small (recomendado)**
```bash
cd pipeline_swift/src
./pipeline-main.sh small
```

### **2. Personalizar arquivo de áudio**
Edite o arquivo `src/pipeline-main.sh` na linha:
```swift
audioFile: "/caminho/para/seu/audio.wav"
```

## ⚙️ **Configurações Avançadas**

### **Performance para diferentes Macs:**

**M1 MacBook Air** (configuração atual):
```swift
let numThreads: Int = 4
let optimizedChunkSize: Float = 15.0
```

**M1 Pro/Max**:
```swift
let numThreads: Int = 6
let optimizedChunkSize: Float = 20.0
```

**M2 Pro/Max**:
```swift
let numThreads: Int = 8
let optimizedChunkSize: Float = 25.0
```

### **Controles de qualidade vs velocidade:**

**Máxima velocidade** (desabilitar denoise):
```swift
let enableDenoise: Bool = false
```

**Máxima qualidade** (habilitar denoise):
```swift
let enableDenoise: Bool = true
```

## 🔧 **Recompilação (se necessário)**

Se você modificou o código fonte da SherpaONNX:

```bash
cd pipeline_swift/scripts
./build-swift-macos.sh
```

## 📊 **Performance Esperada**

| Hardware | Áudio | Tempo | Speedup |
|----------|-------|-------|---------|
| M1 Air | 90s | ~55s | 1.6x |
| M1 Pro | 90s | ~40s | 2.2x |
| M2 Pro | 90s | ~35s | 2.5x |

## 🎛️ **Integração em Aplicações**

### **SwiftUI App**
```swift
import Foundation

class TranscriptionService {
    func transcribe(audioFile: String) -> String {
        // Usar o pipeline como subprocess ou biblioteca
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "./pipeline-main.sh")
        process.arguments = ["small"]
        // ... implementar execução
        return result
    }
}
```

### **Command Line Tool**
```swift
// Usar diretamente as classes do pipeline
let pipeline = FinalPipeline()
let result = pipeline.transcribe(audioFile: "audio.wav")
```

## 🐛 **Troubleshooting**

### **❌ "Context leak detected"**
- Verificar se `asrProvider: "cpu"` está configurado
- Nunca usar Core ML para modelos não-Whisper

### **❌ "Arquivo de modelo não encontrado"**
- Verificar se todos os modelos estão em `models/`
- Executar sempre do diretório `src/`

### **❌ Performance baixa**
- Ajustar `numThreads` para seu Mac
- Desabilitar denoise temporariamente
- Usar chunks maiores (20-30s)

### **❌ Erro de compilação**
- Verificar se Xcode Command Line Tools estão instalados:
  ```bash
  xcode-select --install
  ```
- Verificar se as bibliotecas estão em `build/build-swift-macos/install/lib/`

## 📝 **Estrutura de Arquivos**

```
pipeline_swift/
├── src/
│   ├── pipeline-main.sh          # Script principal
│   ├── SherpaOnnx.swift          # Bindings Swift
│   └── SherpaOnnx-Bridging-Header.h
├── models/
│   ├── sherpa-onnx-whisper-small/
│   ├── sherpa-onnx-pyannote-segmentation-3-0/
│   ├── gtcrn_simple.onnx
│   └── 3dspeaker_speech_eres2net_base_sv_zh-cn_3dspeaker_16k.onnx
├── build/
│   └── build-swift-macos/        # Bibliotecas compiladas
├── scripts/
│   └── build-swift-macos.sh      # Script de recompilação
├── test-pipeline.sh              # Teste automático
├── README.md                     # Documentação
├── INSTALL.md                    # Este arquivo
└── config.json                   # Configurações JSON
```

## 🚀 **Pronto para Produção!**

Este backend foi otimizado especificamente para:
- ✅ Apple Silicon M1/M2
- ✅ Transcrição em português
- ✅ Diarização automática de speakers
- ✅ Redução de ruído
- ✅ Performance máxima para macOS

**Tempo total de processamento**: ~55s para 90s de áudio (M1 Air)
**Qualidade**: Produção ready com diarização e denoise 