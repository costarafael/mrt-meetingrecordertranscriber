#!/bin/bash

echo "🔧 Configurando Multi-Output Device automaticamente..."

# Tentar abrir Audio MIDI Setup
osascript << 'APPLESCRIPT'
tell application "Audio MIDI Setup"
    activate
    delay 2
end tell

tell application "System Events"
    tell process "Audio MIDI Setup"
        -- Tentar clicar no botão +
        try
            click button "+" of window 1
            delay 1
            
            -- Procurar opção "Create Multi-Output Device"
            click menu item "Create Multi-Output Device" of menu 1 of button "+" of window 1
            delay 1
            
            display dialog "Multi-Output Device criado! Configure manualmente adicionando MacBook Air Speakers e MRTAudio 2ch"
        on error
            display dialog "Não foi possível criar automaticamente. Abra Audio MIDI Setup e crie manualmente."
        end try
    end tell
end tell
APPLESCRIPT

echo "✅ Tentativa de criação automática concluída"
echo "Se não funcionou, crie manualmente no Audio MIDI Setup"
