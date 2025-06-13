#!/bin/bash

# Script para analisar logs de debug do ScreenCaptureKit

echo "🔍 Analisando logs de debug do ScreenCaptureKit..."
echo "=============================================="

# Encontrar o arquivo de log mais recente
LOG_FILE=$(ls -t /tmp/screencapturekit_debug_*.log 2>/dev/null | head -1)

if [ -z "$LOG_FILE" ]; then
    echo "❌ Nenhum arquivo de log encontrado em /tmp/"
    echo "   Execute uma gravação primeiro para gerar logs."
    exit 1
fi

echo "📄 Analisando: $LOG_FILE"
echo ""

# Estatísticas básicas
echo "📊 ESTATÍSTICAS BÁSICAS:"
echo "------------------------"
echo "Total de linhas: $(wc -l < "$LOG_FILE")"
echo "Primeiro sample: $(grep "FIRST_SAMPLE" "$LOG_FILE" || echo "Não encontrado")"
echo "Último sample: $(tail -n 20 "$LOG_FILE" | grep "SAMPLE_" | tail -1 || echo "Não encontrado")"
echo ""

# Verificar se houve problemas de saúde
echo "🏥 PROBLEMAS DE SAÚDE DO STREAM:"
echo "-------------------------------"
if grep -q "STREAM_HEALTH_ISSUE" "$LOG_FILE"; then
    echo "⚠️  Problemas detectados:"
    grep "STREAM_HEALTH_ISSUE\|LAST_SAMPLE_TIME\|SAMPLES_FROZEN_AT" "$LOG_FILE"
else
    echo "✅ Nenhum problema de saúde detectado"
fi
echo ""

# Tentativas de recuperação
echo "🔄 TENTATIVAS DE RECUPERAÇÃO:"
echo "----------------------------"
if grep -q "ATTEMPTING_RECOVERY\|EARLY_INSTABILITY" "$LOG_FILE"; then
    echo "🔄 Tentativas encontradas:"
    grep "ATTEMPTING_RECOVERY\|EARLY_INSTABILITY" "$LOG_FILE"
else
    echo "✅ Nenhuma tentativa de recuperação necessária"
fi
echo ""

# Marcos de 1000 samples
echo "🎯 MARCOS DE PROGRESSO (a cada 1000 samples):"
echo "--------------------------------------------"
grep "MILESTONE_1000" "$LOG_FILE" || echo "Nenhum marco atingido"
echo ""

# Timeline dos últimos eventos
echo "⏰ TIMELINE DOS ÚLTIMOS 30 EVENTOS:"
echo "-----------------------------------"
tail -n 30 "$LOG_FILE"
echo ""

# Análise de tempo entre samples
echo "📈 ANÁLISE DE PADRÕES:"
echo "--------------------"
echo "Total de samples registrados: $(grep -c "SAMPLE_" "$LOG_FILE")"
echo "Duração da sessão:"
SESSION_START=$(grep "SESSION_START" "$LOG_FILE" | head -1)
SESSION_END=$(grep "SESSION_END" "$LOG_FILE" | head -1)
echo "  Início: $SESSION_START"
echo "  Fim: $SESSION_END"

# Verificar se o stream parou abruptamente
LAST_SAMPLE_TIME=$(grep "SAMPLE_" "$LOG_FILE" | tail -1 | grep -o '\[[0-9.]*s\]')
STOP_TIME=$(grep "STOP_CAPTURE" "$LOG_FILE" | grep -o '\[[0-9.]*s\]')

if [ ! -z "$LAST_SAMPLE_TIME" ] && [ ! -z "$STOP_TIME" ]; then
    echo "  Último sample: $LAST_SAMPLE_TIME"
    echo "  Stop chamado: $STOP_TIME"
fi

echo ""
echo "🎯 RESUMO DA ANÁLISE:"
echo "====================="
if grep -q "STREAM_HEALTH_ISSUE" "$LOG_FILE"; then
    echo "❌ PROBLEMA DETECTADO: Stream parou de receber samples"
    echo "   Verifique os logs acima para detalhes do timing"
else
    echo "✅ Stream funcionou normalmente até o final"
fi

echo ""
echo "📋 Arquivo de log completo disponível em:"
echo "   $LOG_FILE"