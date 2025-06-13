#!/bin/bash

# Script para executar a aplicação MRT_Three PRODUCTION com Core Audio TAP
# Este script usa o app de produção que já tem permissões concedidas

echo "🚀 Iniciando MRT_Three PRODUCTION com Core Audio TAP Real..."
echo "📍 Localização: $(pwd)"
echo ""

# Verificar se o Production App existe
PRODUCTION_APP="./MRTThree_Production.app"
if [ ! -d "$PRODUCTION_APP" ]; then
    echo "❌ Production App não encontrado em: $PRODUCTION_APP"
    echo "💡 Certifique-se de que o MRTThree_Production.app existe no diretório atual"
    exit 1
fi

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

# Verificar informações do Production App
echo "🔍 Informações do Production App:"
echo "   Identifier: $(codesign -dr- "$PRODUCTION_APP" 2>/dev/null | grep "Identifier=" || echo "Não disponível")"
echo "   Caminho: $PRODUCTION_APP"

echo ""
echo "🎯 Iniciando Production App..."
echo "📝 Para testar Core Audio TAP:"
echo "   1. Marque a caixa 'Gravar com Core Audio Tap' na interface"
echo "   2. Clique em 'Iniciar Nova Gravação'"
echo "   3. Se aparecer prompt de instalação da Helper Tool, aceite"
echo "   4. Teste tocando música/áudio no sistema"
echo "   5. Verifique se o arquivo _sys.m4a tem áudio real"
echo ""
echo "✅ Este app JÁ TEM PERMISSÕES concedidas!"
echo "----------------------------------------"

# Executar o Production App
exec open "$PRODUCTION_APP"