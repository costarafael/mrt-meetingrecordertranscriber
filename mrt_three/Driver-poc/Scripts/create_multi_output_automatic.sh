#!/bin/bash

# =============================================================================
# Script para criar Multi-Output Device automaticamente via AppleScript
# =============================================================================

echo "🔧 Criando Multi-Output Device automaticamente..."
echo "================================================="

# Usar AppleScript para automatizar Audio MIDI Setup
osascript << 'EOF'
tell application "Audio MIDI Setup"
    activate
    delay 1
    
    -- Tentar criar Multi-Output Device
    tell application "System Events"
        tell process "Audio MIDI Setup"
            -- Clicar no botão "+" 
            try
                click button 1 of group 1 of window 1
                delay 0.5
                
                -- Selecionar "Create Multi-Output Device"
                click menu item "Create Multi-Output Device" of menu 1 of button 1 of group 1 of window 1
                delay 1
                
                -- Encontrar e marcar MacBook Air Speakers
                tell table 1 of scroll area 1 of window 1
                    repeat with theRow in rows
                        try
                            if (value of static text 1 of theRow) contains "MacBook" then
                                set value of checkbox 1 of theRow to true
                                exit repeat
                            end if
                        end try
                    end repeat
                end tell
                
                -- Encontrar e marcar MRTAudio
                tell table 1 of scroll area 1 of window 1
                    repeat with theRow in rows
                        try
                            if (value of static text 1 of theRow) contains "MRT" then
                                set value of checkbox 1 of theRow to true
                                exit repeat
                            end if
                        end try
                    end repeat
                end tell
                
                delay 1
                
                -- Fechar Audio MIDI Setup
                tell application "Audio MIDI Setup" to quit
                
                return "SUCCESS: Multi-Output Device criado"
                
            on error errorMessage
                return "ERROR: " & errorMessage
            end try
        end tell
    end tell
end tell
EOF

RESULT=$?

if [ $RESULT -eq 0 ]; then
    echo "✅ Multi-Output Device criado com sucesso!"
    echo ""
    echo "🎯 Agora vá em Preferências do Sistema > Som"
    echo "   e selecione 'Multi-Output Device' como saída"
    echo ""
    echo "✅ Resultado: Áudio normal + captura automática!"
else
    echo "❌ Erro ao criar Multi-Output Device automaticamente"
    echo "   Tente o método manual executando:"
    echo "   ./Scripts/open_audio_midi_setup.sh"
fi