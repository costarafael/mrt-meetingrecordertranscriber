#!/bin/bash

echo "🎵 Teste de Reprodução de Áudio - MRT Passthrough"
echo "==============================================="
echo ""

# Verificar dispositivo atual
echo "🔍 Dispositivo de saída atual:"
osascript -e 'tell application "System Events" to get the output device of (audio output 1 of audio device 1)'

echo ""
echo "📊 Status do sistema de áudio:"
system_profiler SPAudioDataType | grep -A 3 -B 1 "Default.*Device.*Yes"

echo ""
echo "🎧 Testando reprodução de áudio..."
echo "Se o passthrough estiver funcionando, você deve ouvir estas mensagens:"
echo ""

# Teste 1: Mensagem simples
echo "🔊 Teste 1: Mensagem de voz"
say "Testing MRT Audio passthrough - Test number one"
sleep 2

# Teste 2: Reproduzir um beep do sistema
echo "🔔 Teste 2: Som do sistema"
osascript -e 'beep 2'
sleep 2

# Teste 3: Tentar reproduzir áudio com afplay (se disponível)
echo "🎵 Teste 3: Áudio de teste"
if command -v afplay &> /dev/null; then
    # Criar um tom simples de teste
    osascript -e 'do shell script "say -o /tmp/test_audio.aiff \"MRT Audio passthrough test\""'
    if [ -f "/tmp/test_audio.aiff" ]; then
        echo "Reproduzindo arquivo de áudio de teste..."
        afplay /tmp/test_audio.aiff
        rm -f /tmp/test_audio.aiff
    fi
else
    say "Audio file player not available, using voice synthesis instead"
fi

echo ""
echo "🔍 Verificando dispositivos ativos:"
# Listar dispositivos que estão sendo usados atualmente
ps aux | grep -i "audio\|coreaudio" | grep -v grep | head -5

echo ""
echo "📋 Checklist do Teste de Passthrough:"
echo "====================================="
echo ""
echo "✅ Você deve ter ouvido as mensagens de voz claramente"
echo "✅ O áudio deve sair pelos seus fones/alto-falantes habituais"
echo "✅ Não deve haver distorção ou ruído excessivo"
echo "✅ Latência deve ser imperceptível"
echo ""
echo "❌ Se não ouviu nada ou houve problemas:"
echo "   • Verifique se MRTAudio está configurado como saída"
echo "   • Verifique volume do sistema"
echo "   • Teste com outro dispositivo para comparar"
echo ""

# Verificar se há múltiplos dispositivos padrão
default_count=$(system_profiler SPAudioDataType | grep -c "Default.*Device.*Yes")
echo "🔍 Dispositivos padrão detectados: $default_count"

if [ "$default_count" -gt 1 ]; then
    echo "⚠️  Múltiplos dispositivos padrão detectados - isso pode causar conflitos"
    echo "   Dispositivos padrão:"
    system_profiler SPAudioDataType | grep -B 1 "Default.*Device.*Yes" | grep ":" | head -10
fi

echo ""
echo "🎯 Próximos passos se o teste passou:"
echo "   1. Testar com música/vídeo de aplicações reais"
echo "   2. Verificar captura simultânea (gravação)"
echo "   3. Testar mudanças de dispositivo padrão"
echo ""
echo "🔧 Se houver problemas:"
echo "   1. Reiniciar Core Audio: sudo killall -9 coreaudiod"
echo "   2. Reinstalar driver: sudo ./Scripts/update_driver.sh"
echo "   3. Verificar logs: ./Scripts/test_passthrough.sh"