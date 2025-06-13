#!/bin/bash

echo "🎧 TESTE DE CAPTURA DE ÁUDIO - Core Audio TAP Real"
echo "=================================================="
echo ""

# Gerar áudio contínuo de teste
echo "🎵 Iniciando áudio de teste..."
say "Testando captura de áudio do sistema com Core Audio TAP Real. Este áudio será usado para verificar se a implementação está funcionando corretamente." &
AUDIO_PID=$!

echo "🎵 Áudio de teste iniciado (PID: $AUDIO_PID)"
echo ""
echo "📱 INSTRUÇÕES:"
echo "1. Na interface da aplicação CoreAudioTapReal:"
echo "   - Clique em 'Instalar Helper Tool' (vai pedir senha)"
echo "   - Clique em 'Iniciar Captura REAL do Sistema'" 
echo "   - Clique em 'Verificar Status'"
echo "   - Observe se mostra o dispositivo sendo capturado"
echo ""
echo "2. Monitore os logs do sistema:"
echo "   Console.app > Mostrar Mensagens de Debug"
echo "   Busque por: 'AudioCaptureHelper' ou 'CoreAudioTapReal'"
echo ""
echo "3. Quando terminar o teste:"
echo "   - Clique em 'Parar Captura' na aplicação"
echo "   - Execute: kill $AUDIO_PID (para parar o áudio)"
echo ""

# Aguardar 30 segundos tocando áudio
echo "⏱️  Aguardando 30 segundos para você testar..."
sleep 30

echo ""
echo "🔄 Verificando se a aplicação ainda está rodando..."
if pgrep -f "CoreAudioTapReal" > /dev/null; then
    echo "✅ Aplicação ainda está ativa"
else
    echo "❌ Aplicação não está rodando"
fi

echo ""
echo "🛑 Parando áudio de teste..."
kill $AUDIO_PID 2>/dev/null || echo "Áudio já foi finalizado"

echo ""
echo "✅ Teste concluído!"
echo "📋 Verifique os resultados na interface da aplicação"