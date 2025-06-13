#!/bin/bash

echo "🔍 Monitorando logs da transcrição..."
echo "📱 Execute a app e clique no botão '🐛 Debug Forçado'"
echo "=================================================="

# Monitorar logs do console em tempo real
log stream --info --debug --predicate 'process == "MacOSApp"' | grep -E "(DEBUG|TranscriptionWorkflow|MeetingStore|TranscriptionManager|ERROR)" --line-buffered