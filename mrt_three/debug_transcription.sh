#!/bin/bash

echo "🔍 Iniciando debug da transcrição..."
echo "📝 Acompanhe os logs abaixo e clique em 'Transcrever' na aplicação"
echo "=================================="

# Executar a aplicação em background e capturar logs
swift run MacOSApp > app_logs.txt 2>&1 &
APP_PID=$!

echo "🚀 App iniciada (PID: $APP_PID)"
echo "🔍 Monitorando logs..."
echo ""

# Monitorar logs em tempo real
tail -f app_logs.txt | grep -E "(TranscriptionWorkflow|MeetingStore|ERROR|DEBUG)" &
TAIL_PID=$!

echo "⏳ Pressione Ctrl+C para parar o monitoramento"

# Trap para cleanup
trap 'kill $APP_PID $TAIL_PID 2>/dev/null; exit' INT

wait