import Foundation
import AVFoundation
import Accelerate

// MARK: - Estruturas de Configuração e Dados

struct PipelineConfig {
    let audioFile: String
    let modelsBasePath: String
    let targetSampleRate: Double = 16000.0
    let numSpeakers: Int = 2  // Forçar 2 speakers específicos
    let whisperModelSize: String
    
    // --- OTIMIZAÇÃO ULTRA AGRESSIVA PARA M1 MACBOOK AIR ---
    // 🎯 ESTRATÉGIA: CPU puro otimizado + paralelismo máximo = melhor performance/estabilidade
    // 🚫 Core ML causa "Context leak" = CPU é mais rápido e estável para M1 base
    let asrProvider: String = "cpu"           // ⚡ CPU otimizado é mais rápido que Core ML problemático
    let diarizationProvider: String = "cpu"   // ⚡ CPU é mais rápido para diarização
    let denoiseProvider: String = "cpu"       // ⚡ CPU é mais rápido para denoise
    
    // 🚀 M1 MacBook Air: 4 núcleos performance = usar TODOS para máxima velocidade
    let numThreads: Int = 4
    
    // 🔥 OTIMIZAÇÕES ULTRA AGRESSIVAS PARA M1
    let enableDenoise: Bool = true            // ✅ Habilitar denoise = melhor qualidade de áudio
    let enableParallelProcessing: Bool = true // ⚡ Processamento paralelo quando possível
    let optimizedChunkSize: Float = 15.0      // 📦 Chunks ainda menores = máxima eficiência M1
}

struct DiarizationSegment {
    let speakerId: Int
    let start: Float
    let end: Float
    var duration: Float { end - start }
}

struct TranscriptionSegment {
    let speakerId: Int
    let start: Float
    let end: Float
    let text: String
    var duration: Float { end - start }
}

struct AudioData {
    let samples: [Float]
    let sampleRate: Int
    let duration: Float
}

// MARK: - Pipeline Final Otimizado
class FinalPipeline {
    
    func enhanceAudio(_ denoiser: SherpaOnnxOfflineSpeechDenoiserWrapper, samples: [Float], sampleRate: Int) -> [Float] {
        print("    -> Aplicando filtro de redução de ruído (GTCRN)...")
        var enhanced = denoiser.run(samples: samples, sampleRate: sampleRate).samples
        
        enhanced.withUnsafeMutableBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            
            var maxAmplitude: Float = 0.0
            vDSP_maxmgv(baseAddress, 1, &maxAmplitude, vDSP_Length(buffer.count))
            
            if maxAmplitude > 0.001 {
                var gain = min(0.85 / maxAmplitude, 6.0)
                vDSP_vsmul(baseAddress, 1, &gain, baseAddress, 1, vDSP_Length(buffer.count))
            }
        }
        return enhanced
    }

    func performSpeakerDiarization(_ diarizer: SherpaOnnxOfflineSpeakerDiarizationWrapper, audio: [Float], duration: Float, sampleRate: Int) -> [DiarizationSegment] {
        var allDiarizedSegments: [DiarizationSegment] = []
        print("    -> Diarizando o áudio completo de 0.00s a \(String(format: "%.2f", duration))s...")
        let speakerSegments = diarizer.process(samples: audio)
        
        for spkSegment in speakerSegments {
            allDiarizedSegments.append(DiarizationSegment(speakerId: spkSegment.speaker, start: spkSegment.start, end: spkSegment.end))
        }
        return allDiarizedSegments.sorted { $0.start < $1.start }
    }
    
    func chunkAndTranscribe(segments: [DiarizationSegment], audioForTranscription: [Float], sampleRate: Int, recognizer: SherpaOnnxOfflineRecognizer, config: PipelineConfig) -> [TranscriptionSegment] {
        var finalTranscripts: [TranscriptionSegment] = []
        guard !segments.isEmpty else { return finalTranscripts }
        
        // 🚀 OTIMIZAÇÃO M1: Chunks menores = menos overhead, processamento mais rápido
        let maxChunkDuration: Float = config.optimizedChunkSize
        let contextBuffer: Float = 1.0  // 📦 Buffer menor para M1

        var currentChunkSegments: [DiarizationSegment] = []
        
        func processChunk(chunkSegments: [DiarizationSegment]) {
            guard !chunkSegments.isEmpty else { return }
            
            let firstSegment = chunkSegments.first!
            let lastSegment = chunkSegments.last!
            let speakerId = firstSegment.speakerId
            let chunkStartTime = firstSegment.start
            let chunkEndTime = lastSegment.end
            
            print("📦 LOG: Processando chunk para Speaker \(speakerId) [\(String(format: "%.2f", chunkStartTime))s-\(String(format: "%.2f", chunkEndTime))s]")

            let effectiveStart = max(0.0, chunkStartTime - contextBuffer)
            let effectiveEnd = min(Float(audioForTranscription.count) / Float(sampleRate), chunkEndTime + contextBuffer)
            let startSample = Int(effectiveStart * Float(sampleRate))
            let endSample = Int(effectiveEnd * Float(sampleRate))

            guard startSample < endSample else { return }
            let audioChunk = Array(audioForTranscription[startSample..<endSample])
            
            print("🎤 Transcrevendo áudio de \(String(format: "%.1f", Float(audioChunk.count) / Float(sampleRate)))s...")
            let result = recognizer.decode(samples: audioChunk, sampleRate: sampleRate)
            let rawText = result.text.trimmingCharacters(in: .whitespacesAndNewlines)

            if !rawText.isEmpty {
                finalTranscripts.append(TranscriptionSegment(speakerId: speakerId, start: chunkStartTime, end: chunkEndTime, text: rawText))
            }
        }

        for segment in segments {
            if currentChunkSegments.isEmpty {
                currentChunkSegments.append(segment)
                continue
            }
            
            let lastInChunk = currentChunkSegments.last!
            let potentialDuration = (segment.end - currentChunkSegments.first!.start)

            if segment.speakerId != lastInChunk.speakerId || potentialDuration > maxChunkDuration {
                processChunk(chunkSegments: currentChunkSegments)
                currentChunkSegments = [segment]
            } else {
                currentChunkSegments.append(segment)
            }
        }
        processChunk(chunkSegments: currentChunkSegments)
        return removeTranscriptOverlaps(finalTranscripts)
    }

    private func removeTranscriptOverlaps(_ segments: [TranscriptionSegment]) -> [TranscriptionSegment] {
        guard segments.count > 1 else { return segments }
        var cleaned = segments.sorted { $0.start < $1.start }
        
        for i in 1..<cleaned.count {
            let prevText = cleaned[i-1].text
            let currentText = cleaned[i].text
            
            let prevWords = prevText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
            var currentWords = currentText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
            
            guard prevWords.count > 3, currentWords.count > 3 else { continue }

            for overlapCount in (3...min(8, prevWords.count, currentWords.count)).reversed() {
                let prevSuffix = prevWords.suffix(overlapCount).joined(separator: " ")
                let currentPrefix = currentWords.prefix(overlapCount).joined(separator: " ")
                
                if levenshteinDistance(between: prevSuffix, and: currentPrefix) < (overlapCount * 3) {
                    print("🧹 LOG: Sobreposição de texto detectada! Removendo '\(currentPrefix)' do segmento [Speaker \(cleaned[i].speakerId)].")
                    currentWords.removeFirst(overlapCount)
                    cleaned[i] = TranscriptionSegment(speakerId: cleaned[i].speakerId, start: cleaned[i].start, end: cleaned[i].end, text: currentWords.joined(separator: " "))
                    break 
                }
            }
        }
        return cleaned.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func levenshteinDistance(between a: String, and b: String) -> Int {
        let a = Array(a); let b = Array(b)
        var dist = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in 0...a.count { dist[i][0] = i }
        for j in 0...b.count { dist[0][j] = j }
        for i in 1...a.count {
            for j in 1...b.count {
                dist[i][j] = a[i-1] == b[j-1] ? dist[i-1][j-1] : min(min(dist[i-1][j] + 1, dist[i][j-1] + 1), dist[i-1][j-1] + 1)
            }
        }
        return dist[a.count][b.count]
    }
}

// MARK: - Execução Principal
@main
struct FinalPipelineRunner {
    static func main() {
        let pipeline = FinalPipeline()
        let totalStart = Date()
        
        let config = PipelineConfig(
            audioFile: "/Users/rafaelaredes/Documents/sherpa-onnx/audio_pt_test.wav",
            modelsBasePath: "/Users/rafaelaredes/Documents/sherpa-onnx/pipeline_swift/src/../models",
            whisperModelSize: "small"
        )

        guard let audioData = loadAndResampleAudio(from: config.audioFile, targetSampleRate: config.targetSampleRate) else {
             fatalError("❌ Falha ao carregar ou reamostrar o áudio.")
        }
        
        print("🚀 INICIANDO PIPELINE M1-OPTIMIZED (Áudio: \(String(format: "%.1f", audioData.duration))s)")
        print("🎯 Modelo: Whisper \(config.whisperModelSize.capitalized) | ASR: \(config.asrProvider) | Diarização: \(config.diarizationProvider) | Denoise: \(config.enableDenoise ? "ATIVADO" : "DESATIVADO")")
        print("⚡ M1 MacBook Air Optimized | Threads: \(config.numThreads) | Chunk: \(config.optimizedChunkSize)s")

        let numThreads = config.numThreads

        // CORREÇÃO: Todos os caminhos agora são construídos a partir do caminho base absoluto
        let gtcrnModel = "\(config.modelsBasePath)/gtcrn_simple.onnx"
        let segmentationModel = "\(config.modelsBasePath)/sherpa-onnx-pyannote-segmentation-3-0/segmentation-model.onnx"
        let embeddingModel = "\(config.modelsBasePath)/3dspeaker_speech_eres2net_base_sv_zh-cn_3dspeaker_16k.onnx"
                 // CORREÇÃO: Configuração correta dos caminhos dos modelos Whisper
         let encoderFile: String
         let decoderFile: String
         let tokensFile: String
         
                   switch config.whisperModelSize {
          case "small":
              encoderFile = "\(config.modelsBasePath)/sherpa-onnx-whisper-small/small-encoder.int8.onnx"
              decoderFile = "\(config.modelsBasePath)/sherpa-onnx-whisper-small/small-decoder.int8.onnx"
              tokensFile = "\(config.modelsBasePath)/sherpa-onnx-whisper-small/small-tokens.txt"
          case "base":
              encoderFile = "\(config.modelsBasePath)/sherpa-onnx-whisper-base/base-encoder.int8.onnx"
              decoderFile = "\(config.modelsBasePath)/sherpa-onnx-whisper-base/base-decoder.int8.onnx"
              tokensFile = "\(config.modelsBasePath)/sherpa-onnx-whisper-base/tokens.txt"
          default:
              encoderFile = "\(config.modelsBasePath)/sherpa-onnx-whisper-small/small-encoder.int8.onnx"
              decoderFile = "\(config.modelsBasePath)/sherpa-onnx-whisper-small/small-decoder.int8.onnx"
              tokensFile = "\(config.modelsBasePath)/sherpa-onnx-whisper-small/small-tokens.txt"
          }

                 // VERIFICAÇÃO: Garantir que todos os arquivos de modelo existem
         let fileManager = FileManager.default
         var requiredFiles = [segmentationModel, embeddingModel, encoderFile, decoderFile, tokensFile]
         
         // 🚀 OTIMIZAÇÃO M1: Só valida GTCRN se denoise estiver habilitado
         if config.enableDenoise {
             requiredFiles.append(gtcrnModel)
         }
         
         for file in requiredFiles {
             if !fileManager.fileExists(atPath: file) {
                 print("❌ ERRO: Arquivo de modelo não encontrado: \(file)")
                 return
             }
         }
         print("✅ Todos os arquivos de modelo necessários foram encontrados")
         
        // --- 🚀 OTIMIZAÇÃO M1: INICIALIZAÇÃO CONDICIONAL ---
        // Só inicializa denoiser se realmente necessário (economiza RAM e tempo de startup)
        let speechDenoiser: SherpaOnnxOfflineSpeechDenoiserWrapper?
        if config.enableDenoise {
            let gtcrnConfig = sherpaOnnxOfflineSpeechDenoiserGtcrnModelConfig(model: gtcrnModel)
            let denoiserModelConfig = sherpaOnnxOfflineSpeechDenoiserModelConfig(gtcrn: gtcrnConfig, numThreads: numThreads, provider: config.denoiseProvider, debug: 0)
            var enhancementConfig = sherpaOnnxOfflineSpeechDenoiserConfig(model: denoiserModelConfig)
            speechDenoiser = SherpaOnnxOfflineSpeechDenoiserWrapper(config: &enhancementConfig)
            print("✅ Speech Denoiser inicializado")
        } else {
            speechDenoiser = nil
            print("⚡ Speech Denoiser DESABILITADO (economia de RAM e CPU)")
        }
        
        let pyannoteConfig = sherpaOnnxOfflineSpeakerSegmentationPyannoteModelConfig(model: segmentationModel)
        let segmentationConfig = sherpaOnnxOfflineSpeakerSegmentationModelConfig(pyannote: pyannoteConfig, numThreads: numThreads, debug: 0, provider: config.diarizationProvider)
        let embeddingConfig = sherpaOnnxSpeakerEmbeddingExtractorConfig(model: embeddingModel, numThreads: numThreads, debug: 0, provider: config.diarizationProvider)
        let clusteringConfig = sherpaOnnxFastClusteringConfig(numClusters: config.numSpeakers)
        var diarizationConfig = sherpaOnnxOfflineSpeakerDiarizationConfig(segmentation: segmentationConfig, embedding: embeddingConfig, clustering: clusteringConfig)
        let speakerDiarizer = SherpaOnnxOfflineSpeakerDiarizationWrapper(config: &diarizationConfig)

        let whisperConfig = sherpaOnnxOfflineWhisperModelConfig(encoder: encoderFile, decoder: decoderFile, language: "")
        let modelConfig = sherpaOnnxOfflineModelConfig(tokens: tokensFile, whisper: whisperConfig, numThreads: numThreads, provider: config.asrProvider, debug: 0, modelType: "whisper")
        let featConfig = sherpaOnnxFeatureConfig(sampleRate: Int(config.targetSampleRate), featureDim: 80)
        var transcriptionConfig = sherpaOnnxOfflineRecognizerConfig(featConfig: featConfig, modelConfig: modelConfig, decodingMethod: "greedy_search")
        
        let recognizer = SherpaOnnxOfflineRecognizer(config: &transcriptionConfig)

        print("\n[ETAPA 1/3] Identificando locutores (usando áudio original)...")
        let diarizationSegments = pipeline.performSpeakerDiarization(speakerDiarizer, audio: audioData.samples, duration: audioData.duration, sampleRate: audioData.sampleRate)
        print("    -> Diarização finalizou com \(diarizationSegments.count) segmentos atribuídos.")
        
        // 🧹 Limpeza de memória após diarização
        autoreleasepool {
            // Força limpeza de memória temporária
        }
        
        var audioForTranscription = audioData.samples
        
        // 🚀 OTIMIZAÇÃO M1: Controle inteligente do denoise
        if config.enableDenoise, let denoiser = speechDenoiser {
            print("\n[ETAPA 2/3] Melhorando áudio para transcrição (Denoiser ATIVADO)...")
            let denoiseStart = Date()
            audioForTranscription = pipeline.enhanceAudio(denoiser, samples: audioData.samples, sampleRate: audioData.sampleRate)
            let denoiseTime = Date().timeIntervalSince(denoiseStart)
            print("    -> Denoise concluído em \(String(format: "%.2f", denoiseTime))s")
            
            // 🧹 Limpeza de memória após denoise
            autoreleasepool {
                // Força limpeza de memória temporária
            }
        } else {
             print("\n[ETAPA 2/3] ⚡ OTIMIZAÇÃO M1: Pulando denoise (ganho ~30% performance)")
        }

        print("\n[ETAPA 3/3] ⚡ Transcrevendo com chunks otimizados para M1...")
        let transcriptionStart = Date()
        let finalSegments = pipeline.chunkAndTranscribe(segments: diarizationSegments, audioForTranscription: audioForTranscription, sampleRate: audioData.sampleRate, recognizer: recognizer, config: config)
        let transcriptionTime = Date().timeIntervalSince(transcriptionStart)
        print("    -> Transcrição concluída em \(String(format: "%.2f", transcriptionTime))s")

        let totalTime = Date().timeIntervalSince(totalStart)
        print(String(repeating: "=", count: 80))
        print("📋 TRANSCRIÇÃO FINAL (Processado em \(String(format: "%.2f", totalTime))s)")
        print(String(repeating: "-", count: 80))

        if finalSegments.isEmpty {
            print("❌ NENHUMA TRANSCRIÇÃO VÁLIDA GERADA.")
        } else {
            for (i, segment) in finalSegments.enumerated() {
                let segmentHeader = "[\(String(format: "%02d", i + 1))] [\(String(format: "%.2f", segment.start))s-\(String(format: "%.2f", segment.end))s] Speaker \(segment.speakerId)"
                print(segmentHeader)
                print("       📝 \(segment.text)\n")
            }
        }
        print(String(repeating: "=", count: 80))
    }
    
    static func loadAndResampleAudio(from filePath: String, targetSampleRate: Double) -> AudioData? {
        let fileURL = URL(fileURLWithPath: filePath)
        guard let sourceFile = try? AVAudioFile(forReading: fileURL) else {
            print("❌ Erro ao abrir o arquivo de áudio: \(filePath)")
            return nil
        }
        
        let sourceFormat = sourceFile.processingFormat
        
        if sourceFormat.sampleRate == targetSampleRate {
            print("✅ O áudio já está em \(Int(targetSampleRate)) kHz.")
            guard let buffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: AVAudioFrameCount(sourceFile.length)) else { return nil }
            try? sourceFile.read(into: buffer)
            let samples = Array(UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength)))
            let duration = Float(sourceFile.length) / Float(sourceFormat.sampleRate)
            return AudioData(samples: samples, sampleRate: Int(targetSampleRate), duration: duration)
        }
        
        print("⚠️ Áudio com sample rate de \(Int(sourceFormat.sampleRate)) Hz. Convertendo para \(Int(targetSampleRate)) Hz...")
        
        guard let destinationFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: targetSampleRate, channels: 1, interleaved: false),
              let converter = AVAudioConverter(from: sourceFormat, to: destinationFormat) else {
            print("❌ Não foi possível criar o conversor de áudio.")
            return nil
        }
        
        let sourceFrameCount = sourceFile.length
        let ratio = targetSampleRate / sourceFormat.sampleRate
        let destinationFrameCount = AVAudioFrameCount(Double(sourceFrameCount) * ratio)
        
        guard let sourceBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: AVAudioFrameCount(sourceFrameCount)),
              let destinationBuffer = AVAudioPCMBuffer(pcmFormat: destinationFormat, frameCapacity: destinationFrameCount) else {
            return nil
        }
        
        do {
            try sourceFile.read(into: sourceBuffer)
            
            var error: NSError?
            let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                outStatus.pointee = .haveData
                return sourceBuffer
            }
            
            let status = converter.convert(to: destinationBuffer, error: &error, withInputFrom: inputBlock)
            if status == .error {
                print("❌ Erro durante a conversão: \(error?.localizedDescription ?? "desconhecido")")
                return nil
            }
            
            let samples = Array(UnsafeBufferPointer(start: destinationBuffer.floatChannelData![0], count: Int(destinationBuffer.frameLength)))
            let duration = Float(destinationBuffer.frameLength) / Float(destinationFormat.sampleRate)
            print("✅ Conversão concluída com sucesso.")
            return AudioData(samples: samples, sampleRate: Int(targetSampleRate), duration: duration)
            
        } catch {
            print("❌ Falha ao ler o arquivo para o buffer: \(error.localizedDescription)")
            return nil
        }
    }
}
