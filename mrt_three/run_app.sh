#!/bin/bash

# Script para executar a aplicação MRT_Three com Core Audio TAP
# Criado após integração da implementação real

echo "🚀 Iniciando MRT_Three com Core Audio TAP Real..."
echo "📍 Localização: $(pwd)"
echo ""

# Verificar e compilar Helper Tool se necessário
HELPER_TOOL="./HelperTools/AudioCaptureHelper/AudioCaptureHelper"
if [ ! -f "$HELPER_TOOL" ]; then
    echo "🔧 Compilando Helper Tool..."
    cd HelperTools/AudioCaptureHelper
    clang -framework Foundation -framework CoreAudio -framework AudioToolbox -framework Security -o AudioCaptureHelper main.m AudioCaptureService.m
    
    if [ $? -ne 0 ]; then
        echo "❌ Falha na compilação da Helper Tool."
        exit 1
    fi
    
    cd ../..
    echo "✅ Helper Tool compilada com sucesso!"
else
    echo "✅ Helper Tool já compilada"
fi

# Verificar se o executável da aplicação existe
EXECUTABLE="./.build/arm64-apple-macosx/debug/MacOSApp"

if [ ! -f "$EXECUTABLE" ]; then
    echo "🔧 Construindo aplicação..."
    swift build --configuration debug
    
    if [ $? -ne 0 ]; then
        echo "❌ Falha no build. Verifique os erros acima."
        exit 1
    fi
    
    echo "✅ Build concluído com sucesso!"
else
    echo "✅ Aplicação já compilada"
fi

echo ""
echo "🎯 Iniciando aplicação..."
echo "📝 Para testar Core Audio TAP:"
echo "   1. Marque a caixa 'Gravar com Core Audio Tap' na interface"
echo "   2. Clique em 'Iniciar Nova Gravação'"
echo "   3. Se aparecer prompt de instalação da Helper Tool, aceite"
echo "   4. Teste tocando música/áudio no sistema"
echo "   5. Verifique se o arquivo _sys.m4a tem áudio real"
echo ""
echo "🔍 Logs serão exibidos abaixo:"
echo "----------------------------------------"

# Executar a aplicação
exec "$EXECUTABLE"