#!/bin/bash

# Script para testar a aplicação em modo produção
# Com XPC real e Helper Tool

echo "🧪 Testando MRT_Three em modo produção..."
echo "📍 Diretório: $(pwd)"
echo ""

APP_NAME="MRTThree_Production.app"

# Verificar se o bundle existe
if [ ! -d "$APP_NAME" ]; then
    echo "❌ Bundle não encontrado. Execute primeiro:"
    echo "   ./build_production.sh"
    exit 1
fi

echo "✅ Bundle encontrado: $APP_NAME"
echo ""

# Verificar estrutura
echo "🔍 Verificando estrutura do bundle..."
if [ -f "$APP_NAME/Contents/MacOS/MRTThree" ]; then
    echo "✅ Executável principal: OK"
else
    echo "❌ Executável principal: FALTANDO"
fi

if [ -f "$APP_NAME/Contents/Library/LaunchServices/AudioCaptureHelper" ]; then
    echo "✅ Helper Tool: OK"
else
    echo "❌ Helper Tool: FALTANDO"
fi

if [ -f "$APP_NAME/Contents/Info.plist" ]; then
    echo "✅ Info.plist: OK"
else
    echo "❌ Info.plist: FALTANDO"
fi

echo ""
echo "🎯 Iniciando aplicação em modo produção..."
echo "📝 Logs que indicam sucesso do XPC real:"
echo "   - 'Helper Tool instalada com sucesso'"
echo "   - 'Conexão XPC criada e ativada'"
echo "   - 'Core Audio Tap (XPC) iniciado com sucesso'"
echo ""
echo "📝 Se aparecer 'Desenvolvimento: simulando':"
echo "   - Significa que ainda está em modo dev"
echo "   - XPC real requer assinatura de código"
echo ""
echo "🚀 Abrindo aplicação..."
echo "----------------------------------------"

# Abrir a aplicação
open "$APP_NAME"

# Dar tempo para a aplicação abrir
sleep 2

echo ""
echo "✅ Aplicação aberta!"
echo ""
echo "📋 Para testar Core Audio TAP real:"
echo "   1. Marque 'Gravar com Core Audio Tap'"
echo "   2. Clique 'Iniciar Nova Gravação'"
echo "   3. Observe os logs no Console.app (opcional)"
echo "   4. Se pedir permissões de admin, aceite"
echo "   5. Teste tocando música/áudio no sistema"
echo ""
echo "🔍 Verificar sucesso:"
echo "   - Gravação inicia sem erro"
echo "   - Arquivo _sys.m4a tem áudio real"
echo "   - Logs mostram XPC funcionando"
echo ""
echo "⚠️  Se ainda mostrar 'Desenvolvimento':"
echo "   - Normal sem certificado Developer ID"
echo "   - Funcionalidade ainda será testada via simulação"