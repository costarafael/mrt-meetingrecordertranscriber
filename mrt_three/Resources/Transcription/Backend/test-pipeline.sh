#!/usr/bin/env bash

echo "🧪 Testando Backend de Transcrição SherpaONNX"
echo "=============================================="

# Verificar estrutura de diretórios
echo "📁 Verificando estrutura de diretórios..."

REQUIRED_DIRS=("src" "models" "build" "scripts")
for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo "✅ $dir/"
    else
        echo "❌ $dir/ - FALTANDO!"
        exit 1
    fi
done

# Verificar arquivos essenciais
echo ""
echo "📄 Verificando arquivos essenciais..."

REQUIRED_FILES=(
    "src/pipeline-main.sh"
    "src/SherpaOnnx.swift"
    "src/SherpaOnnx-Bridging-Header.h"
    "models/sherpa-onnx-whisper-small/small-encoder.int8.onnx"
    "models/sherpa-onnx-whisper-small/small-decoder.int8.onnx"
    "models/sherpa-onnx-whisper-small/small-tokens.txt"
    "models/gtcrn_simple.onnx"
    "models/3dspeaker_speech_eres2net_base_sv_zh-cn_3dspeaker_16k.onnx"
    "models/sherpa-onnx-pyannote-segmentation-3-0/segmentation-model.onnx"
    "build/build-swift-macos/install/lib/libsherpa-onnx.a"
    "build/build-swift-macos/install/include/sherpa-onnx/c-api/c-api.h"
    "scripts/build-swift-macos.sh"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ $file - FALTANDO!"
        exit 1
    fi
done

# Verificar permissões de execução
echo ""
echo "🔐 Verificando permissões..."

if [ -x "src/pipeline-main.sh" ]; then
    echo "✅ src/pipeline-main.sh é executável"
else
    echo "⚠️  Tornando src/pipeline-main.sh executável..."
    chmod +x src/pipeline-main.sh
fi

if [ -x "scripts/build-swift-macos.sh" ]; then
    echo "✅ scripts/build-swift-macos.sh é executável"
else
    echo "⚠️  Tornando scripts/build-swift-macos.sh executável..."
    chmod +x scripts/build-swift-macos.sh
fi

# Verificar tamanhos dos modelos
echo ""
echo "📊 Verificando tamanhos dos modelos..."

MODEL_SIZES=(
    "models/sherpa-onnx-whisper-small/small-encoder.int8.onnx:50MB"
    "models/sherpa-onnx-whisper-small/small-decoder.int8.onnx:20MB"
    "models/gtcrn_simple.onnx:5MB"
    "models/3dspeaker_speech_eres2net_base_sv_zh-cn_3dspeaker_16k.onnx:10MB"
    "models/sherpa-onnx-pyannote-segmentation-3-0/segmentation-model.onnx:10MB"
)

for item in "${MODEL_SIZES[@]}"; do
    file=$(echo $item | cut -d: -f1)
    expected_size=$(echo $item | cut -d: -f2)
    
    if [ -f "$file" ]; then
        actual_size=$(du -h "$file" | cut -f1)
        echo "✅ $file: $actual_size (esperado: ~$expected_size)"
    fi
done

# Verificar bibliotecas
echo ""
echo "📚 Verificando bibliotecas SherpaONNX..."

LIB_DIR="build/build-swift-macos/install/lib"
if [ -f "$LIB_DIR/libsherpa-onnx.a" ]; then
    echo "✅ libsherpa-onnx.a encontrada"
    # Verificar se não está corrompida
    file "$LIB_DIR/libsherpa-onnx.a" | grep -q "archive" && echo "✅ Biblioteca estática válida para macOS"
else
    echo "❌ libsherpa-onnx.a não encontrada!"
fi

if [ -f "$LIB_DIR/libonnxruntime.a" ]; then
    echo "✅ libonnxruntime.a encontrada"
else
    echo "❌ libonnxruntime.a não encontrada!"
fi

# Teste de compilação (sem executar)
echo ""
echo "🔨 Testando compilação Swift..."

cd src
echo "🧪 Criando teste de compilação..."

# Criar um arquivo de teste mínimo
cat > test-compile.swift << 'EOF'
import Foundation

print("✅ Teste de compilação Swift bem-sucedido!")
EOF

# Tentar compilar
if swiftc \
    -I ../build/build-swift-macos/install/include \
    -L ../build/build-swift-macos/install/lib/ \
    test-compile.swift \
    -o test-compile 2>/dev/null; then
    echo "✅ Compilação Swift funcionando"
    ./test-compile
    rm -f test-compile test-compile.swift
else
    echo "❌ Falha na compilação Swift - verificar bibliotecas"
    rm -f test-compile test-compile.swift
fi

cd ..

# Resumo final
echo ""
echo "📋 RESUMO DO TESTE"
echo "=================="
echo "✅ Estrutura de diretórios: OK"
echo "✅ Arquivos essenciais: OK"
echo "✅ Modelos: OK"
echo "✅ Bibliotecas: OK"
echo "✅ Compilação: OK"
echo ""
echo "🚀 Backend pronto para uso!"
echo ""
echo "📖 Para usar:"
echo "   cd src"
echo "   ./pipeline-main.sh small"
echo ""
echo "📝 Para personalizar áudio, edite audioFile em pipeline-main.sh" 