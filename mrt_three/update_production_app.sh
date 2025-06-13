#!/bin/bash

# Script para atualizar o Production App com as correções de permissões
echo "🔄 Atualizando MRTThree_Production.app com correções de permissões..."
echo ""

# Verificar se existe backup
if [ ! -d "MRTThree_Production.app.backup" ]; then
    echo "💾 Criando backup do Production App..."
    cp -r MRTThree_Production.app MRTThree_Production.app.backup
    echo "✅ Backup criado: MRTThree_Production.app.backup"
else
    echo "✅ Backup já existe: MRTThree_Production.app.backup"
fi

# Verificar se temos o binary atualizado
RELEASE_BINARY=".build/arm64-apple-macosx/release/MacOSApp"
if [ ! -f "$RELEASE_BINARY" ]; then
    echo "🔧 Compilando versão release com correções..."
    swift build -c release
    
    if [ $? -ne 0 ]; then
        echo "❌ Falha no build. Verifique os erros."
        exit 1
    fi
fi

# Verificar datas para confirmar que temos a versão mais recente
echo "📅 Verificando datas dos arquivos:"
echo "   Production App: $(stat -f "%Sm" -t "%Y-%m-%d %H:%M" MRTThree_Production.app/Contents/MacOS/MRTThree)"
echo "   Release Binary: $(stat -f "%Sm" -t "%Y-%m-%d %H:%M" $RELEASE_BINARY)"

# Atualizar o executável principal
echo ""
echo "🔄 Atualizando executável principal..."
cp "$RELEASE_BINARY" MRTThree_Production.app/Contents/MacOS/MRTThree
chmod +x MRTThree_Production.app/Contents/MacOS/MRTThree
echo "✅ Executável atualizado com correções de permissões"

# Atualizar Info.plist com descrições de permissão melhoradas
if [ -f "Info.plist" ]; then
    echo "🔄 Atualizando Info.plist..."
    cp Info.plist MRTThree_Production.app/Contents/Info.plist
    echo "✅ Info.plist atualizado com descrições de permissão melhoradas"
else
    echo "⚠️  Info.plist não encontrado - mantendo o atual"
fi

# Verificar Helper Tool
HELPER_IN_APP="MRTThree_Production.app/Contents/Library/LaunchServices/AudioCaptureHelper"
HELPER_SOURCE="HelperTools/AudioCaptureHelper/AudioCaptureHelper"

if [ -f "$HELPER_SOURCE" ]; then
    echo "🔄 Atualizando Helper Tool..."
    cp "$HELPER_SOURCE" "$HELPER_IN_APP"
    chmod +x "$HELPER_IN_APP"
    echo "✅ Helper Tool atualizada"
elif [ ! -f "$HELPER_IN_APP" ]; then
    echo "🔧 Compilando Helper Tool..."
    cd HelperTools/AudioCaptureHelper
    clang -framework Foundation -framework CoreAudio -framework AudioToolbox -framework Security -o AudioCaptureHelper main.m AudioCaptureService.m
    
    if [ $? -eq 0 ]; then
        cd ../..
        mkdir -p MRTThree_Production.app/Contents/Library/LaunchServices
        cp "$HELPER_SOURCE" "$HELPER_IN_APP"
        chmod +x "$HELPER_IN_APP"
        echo "✅ Helper Tool compilada e instalada"
    else
        echo "❌ Falha na compilação da Helper Tool"
        cd ../..
    fi
else
    echo "✅ Helper Tool já presente"
fi

echo ""
echo "🎯 Production App atualizado com sucesso!"
echo ""
echo "📋 Resumo das correções aplicadas:"
echo "   ✅ Correção da condição de corrida em permissões"
echo "   ✅ Verificação de status de permissões melhorada"
echo "   ✅ Aguarda resposta do usuário antes de mostrar erros"
echo "   ✅ Descrições de permissão em português"
echo ""
echo "🚀 Para testar, execute:"
echo "   ./run_production_app.sh"
echo ""
echo "💡 O app agora deve solicitar permissões corretamente sem mostrar"
echo "   erros enquanto o usuário ainda está respondendo aos diálogos!"