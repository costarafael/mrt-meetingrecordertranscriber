#!/usr/bin/env swift

import Foundation

// Simulação de teste para verificar o fluxo de transcrição
print("🔍 Teste de Transcrição")
print("======================")

// 1. Verificar se FFmpeg existe
let ffmpegPath = "/opt/homebrew/bin/ffmpeg"
if FileManager.default.fileExists(atPath: ffmpegPath) {
    print("✅ FFmpeg encontrado: \(ffmpegPath)")
} else {
    print("❌ FFmpeg não encontrado em: \(ffmpegPath)")
}

// 2. Verificar se pipeline existe
let pipelinePath = "/Users/rafaelaredes/Documents/mrt_macos/mrt_three/Resources/Transcription/Backend/src/pipeline-optimized-small"
if FileManager.default.fileExists(atPath: pipelinePath) {
    print("✅ Pipeline encontrado: \(pipelinePath)")
    
    // Verificar permissões
    let attributes = try? FileManager.default.attributesOfItem(atPath: pipelinePath)
    if let perms = attributes?[.posixPermissions] as? NSNumber {
        print("   Permissões: \(String(perms.uint16Value, radix: 8))")
    }
} else {
    print("❌ Pipeline não encontrado em: \(pipelinePath)")
}

// 3. Verificar arquivos de audio exemplo
let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
let audioPath = (documentsPath as NSString).appendingPathComponent("MeetingRecordings")
print("📁 Diretório de reuniões: \(audioPath)")

if FileManager.default.fileExists(atPath: audioPath) {
    do {
        let files = try FileManager.default.contentsOfDirectory(atPath: audioPath)
        let combinedFiles = files.filter { $0.hasSuffix("_combined.m4a") }
        print("🎵 Arquivos _combined.m4a encontrados: \(combinedFiles.count)")
        
        for file in combinedFiles.prefix(3) {
            let fullPath = (audioPath as NSString).appendingPathComponent(file)
            let size = try? FileManager.default.attributesOfItem(atPath: fullPath)[.size] as? Int64
            print("   - \(file) (\(size ?? 0) bytes)")
        }
    } catch {
        print("❌ Erro ao listar arquivos: \(error)")
    }
} else {
    print("❌ Diretório de reuniões não existe")
}

print("\n📝 Execute este script para diagnosticar o ambiente:")
print("   swift test_transcription.swift")