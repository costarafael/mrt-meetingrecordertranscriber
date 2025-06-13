#!/bin/bash

# Script para testar a funcionalidade de passthrough do driver MRT
# Executa testes automatizados e guia o usuário para testes manuais

set -e

echo "🧪 Teste de Passthrough - MRT Audio Driver"
echo "==========================================="
echo ""

# Diretórios
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POC_DIR="$(dirname "$SCRIPT_DIR")"
INSTALL_PATH="/Library/Audio/Plug-Ins/HAL/MRTAudioDriver.driver"

# Verificar se driver está instalado
if [ ! -d "$INSTALL_PATH" ]; then
    echo "❌ Driver MRT Audio não está instalado"
    echo "Execute: sudo ./Scripts/update_driver.sh"
    exit 1
fi

echo "✅ Driver MRT Audio encontrado"
echo ""

# Teste 1: Verificar se driver aparece no sistema
echo "🔍 Teste 1: Detecção do Driver"
echo "-----------------------------"

# Usar aplicação Swift para verificar driver
cd "$POC_DIR/ControlApp"
echo "Executando aplicação de controle..."
swift run MRTDriverControl 2>/dev/null || {
    echo "⚠️  Erro ao executar aplicação de controle"
    echo "Tentando método alternativo..."
}

echo ""

# Teste 2: Verificar no Audio MIDI Setup
echo "🎛️  Teste 2: Audio MIDI Setup"
echo "-----------------------------"
echo "Abrindo Audio MIDI Setup para verificação visual..."
echo ""
echo "No Audio MIDI Setup, procure por:"
echo "• Dispositivo 'MRTAudio 2ch' na lista"
echo "• Configure como dispositivo de saída para testar"
echo ""

# Aguardar confirmação do usuário
read -p "Pressione ENTER para abrir Audio MIDI Setup..." 
open "/Applications/Utilities/Audio MIDI Setup.app"

echo ""
echo "⏳ Aguardando 5 segundos para Audio MIDI Setup abrir..."
sleep 5

# Teste 3: Instruções de teste manual
echo ""
echo "🎵 Teste 3: Teste Manual de Passthrough"
echo "--------------------------------------"
echo ""
echo "Para testar o passthrough, siga estes passos:"
echo ""
echo "1️⃣  Configure o MRTAudio como saída:"
echo "    • Abra Preferências do Sistema > Som"
echo "    • Ou use o comando: open '/System/Library/PreferencePanes/Sound.prefPane'"
echo "    • Selecione 'MRTAudio 2ch' como dispositivo de saída"
echo ""
echo "2️⃣  Teste reprodução de áudio:"
echo "    • Reproduza música no Spotify/Apple Music"
echo "    • Assista um vídeo no YouTube/Safari"
echo "    • Execute: say 'Testing MRT Audio passthrough'"
echo ""
echo "3️⃣  Verifique o passthrough:"
echo "    • ✅ Você DEVE ouvir o áudio normalmente"
echo "    • ✅ Áudio é roteado para seus fones/alto-falantes padrão"
echo "    • ✅ MRT captura o áudio para gravação simultaneamente"
echo ""
echo "4️⃣  Teste mudança de dispositivos:"
echo "    • Mude dispositivo de saída padrão (fones → alto-falantes)"
echo "    • Áudio deve continuar sendo ouvido no novo dispositivo"
echo ""

# Opção de teste automático de som
echo "🔊 Teste 4: Teste Automático de Som"
echo "-----------------------------------"
read -p "Deseja executar teste de som automático? (y/N): " test_sound

if [[ $test_sound =~ ^[Yy]$ ]]; then
    echo ""
    echo "🎙️  Executando teste de voz..."
    echo "Se o passthrough estiver funcionando, você deve ouvir esta mensagem:"
    sleep 1
    say "Testing MRT Audio Driver passthrough functionality. If you can hear this message, the passthrough is working correctly."
    sleep 3
    echo "✅ Teste de voz concluído"
fi

echo ""
echo "🔧 Teste 5: Verificação Técnica"
echo "-------------------------------"
echo "Verificando logs do sistema para atividade do driver..."

# Verificar logs recentes relacionados ao driver
echo "Logs recentes do Core Audio:"
log show --predicate 'process == "coreaudiod"' --info --last 1m 2>/dev/null | grep -i "mrt\|audio" | tail -5 || echo "Nenhum log específico encontrado"

echo ""
echo "🔍 Comandos úteis para debugging:"
echo "• Listar todos os dispositivos: system_profiler SPAudioDataType"
echo "• Reiniciar Core Audio: sudo killall -9 coreaudiod"
echo "• Ver logs em tempo real: log stream --predicate 'process == \"coreaudiod\"'"

echo ""
echo "📊 Resumo do Teste"
echo "=================="
echo ""
echo "Se o passthrough estiver funcionando corretamente:"
echo "✅ MRTAudio 2ch aparece como dispositivo de saída"
echo "✅ Áudio é reproduzido normalmente quando MRT é selecionado"
echo "✅ Áudio é roteado para saída padrão do usuário"
echo "✅ MRT captura áudio para gravação simultaneamente"
echo "✅ Mudanças de dispositivo padrão são detectadas"
echo ""
echo "❌ Se algo não funcionar:"
echo "• Reinstale o driver: sudo ./Scripts/update_driver.sh"
echo "• Reinicie Core Audio: sudo killall -9 coreaudiod"
echo "• Verifique permissões: ls -la $INSTALL_PATH"
echo ""
echo "🎯 Próximos passos se tudo funcionar:"
echo "• Integrar driver no projeto MRT principal"
echo "• Testar com gravação real de reuniões"
echo "• Migrar para AudioDriverKit (System Extension)"

echo ""
read -p "Pressione ENTER para abrir Preferências de Som e testar..."
open "/System/Library/PreferencePanes/Sound.prefPane"