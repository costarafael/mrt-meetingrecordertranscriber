# 🎤 Backend de Transcrição SherpaONNX para macOS

Este diretório contém um **backend completo de transcrição** otimizado para **Apple Silicon M1/M2** com:
- ✅ **Diarização de speakers** (auto-detecção)
- ✅ **Transcrição em português** (Whisper Small)
- ✅ **Redução de ruído** (GTCRN)
- ✅ **Otimizado para M1 MacBook Air**

## 📁 **Estrutura do Projeto**

```
pipeline_swift/
├── src/                          # 📝 Código fonte
│   ├── pipeline-main.sh          # 🚀 Script principal otimizado
│   ├── SherpaOnnx.swift          # 🔧 Bindings Swift da SherpaONNX
│   └── SherpaOnnx-Bridging-Header.h # 🌉 Header para interoperabilidade C++
├── models/                       # 🤖 Modelos de IA
│   ├── sherpa-onnx-whisper-small/ # 🎯 Whisper Small (transcrição)
│   ├── sherpa-onnx-pyannote-segmentation-3-0/ # 👥 Diarização de speakers
│   ├── gtcrn_simple.onnx         # 🔇 Redução de ruído
│   └── 3dspeaker_speech_eres2net_base_sv_zh-cn_3dspeaker_16k.onnx # 🔊 Speaker embedding
├── build/                        # 🏗️ Bibliotecas compiladas
│   └── build-swift-macos/        # 📚 SherpaONNX compilada para Swift/macOS
├── scripts/                      # 🛠️ Scripts auxiliares
│   └── build-swift-macos.sh      # 🔨 Script para recompilar SherpaONNX

```

## 🚀 **Como Usar**

### 1️⃣ **Executar transcrição:**
```bash
cd pipeline_swift/src
./pipeline-main.sh small
```

### 2️⃣ **Personalizar áudio:**
Edite a linha no script:
```swift
audioFile: "/caminho/para/seu/audio.wav"
```

## ⚙️ **Configurações Otimizadas**

### 🎯 **Performance M1 MacBook Air:**
- **CPU**: 4 threads (aproveita todos os núcleos performance)
- **Chunks**: 15 segundos (otimizado para M1)
- **Providers**: CPU puro (evita leaks do Core ML)
- **Auto-detecção**: Speakers automático

### 🔧 **Configurações editáveis:**
```swift
struct PipelineConfig {
    let numSpeakers: Int = 0          // 0 = auto-detect
    let enableDenoise: Bool = true    // true/false
    let numThreads: Int = 4           // 1-8 threads
    let optimizedChunkSize: Float = 15.0 // segundos
}
```

## 📊 **Performance Esperada**

| Hardware | Áudio | Tempo | Speedup |
|----------|-------|-------|---------|
| M1 MacBook Air | 90s | ~55s | 1.6x |
| M1 Pro | 90s | ~40s | 2.2x |
| M2 Pro | 90s | ~35s | 2.5x |

## 🔧 **Recompilação (se necessário)**

Se precisar recompilar a SherpaONNX:
```bash
cd pipeline_swift/scripts
./build-swift-macos.sh
```

## 🎛️ **Controles Avançados**

### **Desabilitar denoise** (ganho ~20% velocidade):
```swift
let enableDenoise: Bool = false
```

### **Ajustar threads para seu Mac**:
- M1 Air: `4 threads`
- M1 Pro: `6 threads` 
- M2 Pro/Max: `8 threads`

### **Chunks menores** (mais responsivo):
```swift
let optimizedChunkSize: Float = 10.0  // 10 segundos
```

## 🐛 **Troubleshooting**

### ❌ **"Context leak detected"**
- Verificar se está usando `asrProvider: "cpu"`
- Nunca usar Core ML em modelos não-Whisper

### ❌ **"Arquivo de modelo não encontrado"**
- Verificar se todos os modelos estão em `models/`
- Executar do diretório `src/`

### ❌ **Performance baixa**
- Verificar número de threads
- Desabilitar denoise temporariamente
- Usar chunks maiores (20-30s)

## 🎯 **Integração em App macOS**

Este pipeline pode ser facilmente integrado em:
- ✅ Apps SwiftUI
- ✅ Command line tools
- ✅ Background services
- ✅ Web servers (Vapor, etc.)

### **Exemplo básico de integração:**
```swift
// No seu app Swift
let pipeline = FinalPipeline()
let result = pipeline.transcribe(audioFile: "audio.wav")
```

## 📝 **Licença e Créditos**

- **SherpaONNX**: [k2-fsa/sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx)
- **Whisper**: OpenAI
- **Pyannote**: CNRS/IRIT
- **Otimizações M1**: Customizadas para este projeto

---

🚀 **Pipeline otimizado para produção em macOS Apple Silicon!** 