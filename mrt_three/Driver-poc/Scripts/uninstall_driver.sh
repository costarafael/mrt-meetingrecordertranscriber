#!/bin/bash

# Script para desinstalar o driver MRT Audio
# DEVE SER EXECUTADO COM SUDO

set -e

if [ "$EUID" -ne 0 ]; then
    echo "❌ Este script deve ser executado como root (sudo)"
    exit 1
fi

echo "🗑️  Desinstalando MRT Audio Driver..."

DRIVER_PATH="/Library/Audio/Plug-Ins/HAL/MRTAudioDriver.driver"

# Verificar se o driver está instalado
if [ ! -d "$DRIVER_PATH" ]; then
    echo "ℹ️  Driver MRT Audio não está instalado"
    exit 0
fi

# Parar aplicações de áudio
echo "⏸️  Parando aplicações de áudio..."
pkill -f "coreaudiod" 2>/dev/null || true

# Remover driver
echo "🗑️  Removendo driver..."
rm -rf "$DRIVER_PATH"

# Reiniciar Core Audio
echo "🔄 Reiniciando Core Audio..."
killall -9 coreaudiod 2>/dev/null || true

# Aguardar reinicialização
sleep 2

echo "✅ Driver MRT Audio desinstalado com sucesso!"
echo ""
echo "⚠️  Pode ser necessário reiniciar aplicações de áudio."