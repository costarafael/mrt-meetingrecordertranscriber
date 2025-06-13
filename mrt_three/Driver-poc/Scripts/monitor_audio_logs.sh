#!/bin/bash

# =============================================================================
# MONITOR DE LOGS - Investigar por que passthrough não funciona
# =============================================================================

echo "🔍 INICIANDO MONITORAMENTO DE LOGS DO CORE AUDIO"
echo "================================================"

LOG_DIR="/Users/rafaelaredes/Documents/mrt_macos/mrt_three/Driver-poc/logs"
mkdir -p "$LOG_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/audio_debug_$TIMESTAMP.log"

echo "📋 Logs serão salvos em: $LOG_FILE"

# Função para capturar logs relevantes
capture_logs() {
    echo "=== INICIANDO CAPTURA DE LOGS === $(date)" >> "$LOG_FILE"
    
    # 1. Logs do CoreAudio
    echo "" >> "$LOG_FILE"
    echo "1. LOGS DO COREAUDIO (últimos 5 minutos):" >> "$LOG_FILE"
    echo "----------------------------------------" >> "$LOG_FILE"
    log show --predicate 'category == "CoreAudio" || subsystem == "com.apple.audio"' --last 5m >> "$LOG_FILE" 2>&1
    
    # 2. Logs específicos do nosso driver
    echo "" >> "$LOG_FILE"
    echo "2. LOGS DO DRIVER MRT (últimos 5 minutos):" >> "$LOG_FILE"
    echo "-----------------------------------------" >> "$LOG_FILE"
    log show --predicate 'eventMessage contains "MRT"' --last 5m >> "$LOG_FILE" 2>&1
    
    # 3. Logs de AudioServerPlugIn
    echo "" >> "$LOG_FILE"
    echo "3. LOGS DO AUDIOSERVERPLUGIN:" >> "$LOG_FILE"
    echo "-----------------------------" >> "$LOG_FILE"
    log show --predicate 'category == "AudioServerPlugIn"' --last 5m >> "$LOG_FILE" 2>&1
    
    # 4. Console específico para audio
    echo "" >> "$LOG_FILE"
    echo "4. CONSOLE AUDIO (últimos 2 minutos):" >> "$LOG_FILE"
    echo "-------------------------------------" >> "$LOG_FILE"
    log show --style syslog --predicate 'eventMessage contains "audio" || eventMessage contains "Audio"' --last 2m >> "$LOG_FILE" 2>&1
    
    # 5. Verificar se driver está carregado
    echo "" >> "$LOG_FILE"
    echo "5. STATUS DO DRIVER:" >> "$LOG_FILE"
    echo "-------------------" >> "$LOG_FILE"
    system_profiler SPAudioDataType | grep -A 5 -B 5 "MRT" >> "$LOG_FILE" 2>&1
    
    echo "" >> "$LOG_FILE"
    echo "=== FIM DA CAPTURA === $(date)" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
}

# Captura inicial
echo "📊 Capturando estado inicial..."
capture_logs

echo ""
echo "🎯 INSTRUÇÕES PARA DIAGNÓSTICO:"
echo "==============================="
echo ""
echo "1. 🎵 AGORA toque algum áudio (YouTube, música, etc)"
echo "2. 🔊 Configure MRTAudio 2ch como saída de som"
echo "3. ⏰ Aguarde 30 segundos"
echo "4. ⌨️  Pressione ENTER para capturar logs durante reprodução"

read -p "Pressione ENTER quando estiver reproduzindo áudio..."

echo "📊 Capturando logs durante reprodução..."
capture_logs

echo ""
echo "🔧 DIAGNÓSTICO ADICIONAL:"
echo "========================="

# Verificar dispositivos de áudio
echo "📱 Listando dispositivos de áudio:" | tee -a "$LOG_FILE"
system_profiler SPAudioDataType | grep -E "(Name|Device ID)" | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"

# Verificar saída padrão atual
echo "🎯 Dispositivo de saída atual:" | tee -a "$LOG_FILE"
osascript -e 'tell application "System Events" to tell process "System Preferences" to get properties' 2>/dev/null || echo "Erro ao verificar" | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"

# Verificar se o driver está respondendo
echo "🔌 Testando comunicação com driver:" | tee -a "$LOG_FILE"
if [ -f "/Users/rafaelaredes/Documents/mrt_macos/mrt_three/Driver-poc/ControlApp/.build/debug/ControlApp" ]; then
    /Users/rafaelaredes/Documents/mrt_macos/mrt_three/Driver-poc/ControlApp/.build/debug/ControlApp 2>&1 | tee -a "$LOG_FILE"
else
    echo "⚠️  ControlApp não encontrado" | tee -a "$LOG_FILE"
fi

echo ""
echo "✅ LOGS CAPTURADOS!"
echo "=================="
echo ""
echo "📄 Arquivo de log: $LOG_FILE"
echo ""
echo "🔍 ANÁLISE RÁPIDA:"
echo "-----------------"

# Buscar por erros críticos
echo "❌ Erros encontrados:"
grep -i "error\|fail\|denied\|cannot" "$LOG_FILE" | head -10

echo ""
echo "⚠️  Avisos encontrados:"
grep -i "warning\|warn" "$LOG_FILE" | head -5

echo ""
echo "🎯 Mensagens do driver MRT:"
grep -i "mrt\|mrtaudio" "$LOG_FILE" | head -10

echo ""
echo "💡 VERIFICAÇÕES RECOMENDADAS:"
echo "1. Verifique se há erros de permissão"
echo "2. Confirme se o driver está carregado corretamente"
echo "3. Teste se outras aplicações de áudio funcionam"
echo ""
echo "📋 Próximo passo: Analise o arquivo $LOG_FILE"