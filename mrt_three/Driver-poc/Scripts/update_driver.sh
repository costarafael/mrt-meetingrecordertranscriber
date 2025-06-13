#!/bin/bash

# Script para atualizar o driver MRT Audio (desinstala antigo + instala novo)
# DEVE SER EXECUTADO COM SUDO

set -e

if [ "$EUID" -ne 0 ]; then
    echo "❌ Este script deve ser executado como root (sudo)"
    exit 1
fi

echo "🔄 Atualizando MRT Audio Driver..."
echo ""

# Diretórios
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POC_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$POC_DIR/build"
DRIVER_PATH="$BUILD_DIR/Release/MRTAudioDriver.driver"
INSTALL_PATH="/Library/Audio/Plug-Ins/HAL/MRTAudioDriver.driver"

# Verificar se o novo driver foi compilado
if [ ! -d "$DRIVER_PATH" ]; then
    echo "❌ Driver atualizado não encontrado em: $DRIVER_PATH"
    echo "Execute primeiro: ./Scripts/build_driver.sh"
    exit 1
fi

# Passo 1: Desinstalar driver antigo (se existir)
if [ -d "$INSTALL_PATH" ]; then
    echo "🗑️  Passo 1/3: Desinstalando driver antigo..."
    bash "$SCRIPT_DIR/uninstall_driver.sh"
    echo ""
else
    echo "ℹ️  Passo 1/3: Nenhum driver anterior encontrado - continuando..."
    echo ""
fi

# Passo 2: Aguardar Core Audio estabilizar
echo "⏸️  Passo 2/3: Aguardando Core Audio estabilizar..."
sleep 3
echo ""

# Passo 3: Instalar novo driver
echo "📦 Passo 3/3: Instalando driver atualizado..."
bash "$SCRIPT_DIR/install_driver.sh"

echo ""
echo "🎉 Atualização do MRT Audio Driver concluída!"
echo ""
echo "🔍 Para verificar a instalação:"
echo "   ./Scripts/test_driver.sh"
echo "   cd ControlApp && swift run MRTDriverControl"
echo ""
echo "💡 Funcionalidades do driver atualizado:"
echo "   ✅ Passthrough automático para saída padrão"
echo "   ✅ Detecção de mudanças de dispositivos"
echo "   ✅ Captura transparente de áudio"
echo "   ✅ Thread-safe audio processing"