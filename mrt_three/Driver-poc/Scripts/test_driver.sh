#!/bin/bash

# Script para testar o driver MRT Audio

echo "🧪 Testando MRT Audio Driver..."

# Diretórios
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POC_DIR="$(dirname "$SCRIPT_DIR")"
CONTROL_APP_DIR="$POC_DIR/ControlApp"

# Compilar e executar aplicação de controle
echo "🔧 Compilando aplicação de controle..."
cd "$CONTROL_APP_DIR"

swift build -c release

if [ $? -eq 0 ]; then
    echo "✅ Aplicação de controle compilada!"
    echo ""
    echo "📊 Executando verificação do driver..."
    echo "================================================"
    .build/release/MRTDriverControl
    echo "================================================"
else
    echo "❌ Erro na compilação da aplicação de controle!"
    exit 1
fi

echo ""
echo "🔍 Verificações adicionais:"
echo ""

# Verificar se o arquivo do driver existe
DRIVER_PATH="/Library/Audio/Plug-Ins/HAL/MRTAudioDriver.driver"
if [ -d "$DRIVER_PATH" ]; then
    echo "✅ Arquivo do driver encontrado: $DRIVER_PATH"
    
    # Mostrar informações do arquivo
    echo "📋 Informações do arquivo:"
    ls -la "$DRIVER_PATH/Contents/MacOS/"
    
    echo ""
    echo "🔐 Verificação de assinatura:"
    codesign -v "$DRIVER_PATH" 2>/dev/null && echo "✅ Driver assinado corretamente" || echo "⚠️  Driver não assinado (normal para desenvolvimento)"
else
    echo "❌ Arquivo do driver não encontrado!"
fi

echo ""
echo "🎵 Para testar o driver:"
echo "1. Abra 'Audio MIDI Setup' (/Applications/Utilities/)"
echo "2. Procure por dispositivos 'MRTAudio'"
echo "3. Teste gravação/reprodução através do driver"
echo ""
echo "🔄 Se o driver não aparecer, tente:"
echo "   sudo killall -9 coreaudiod"