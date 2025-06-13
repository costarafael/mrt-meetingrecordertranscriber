#!/bin/bash

# Script para instalar o driver MRT Audio
# DEVE SER EXECUTADO COM SUDO

set -e

if [ "$EUID" -ne 0 ]; then
    echo "❌ Este script deve ser executado como root (sudo)"
    exit 1
fi

echo "📦 Instalando MRT Audio Driver..."

# Diretórios
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POC_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$POC_DIR/build"
DRIVER_PATH="$BUILD_DIR/Release/MRTAudioDriver.driver"
INSTALL_PATH="/Library/Audio/Plug-Ins/HAL/MRTAudioDriver.driver"

# Verificar se o driver foi compilado
if [ ! -d "$DRIVER_PATH" ]; then
    echo "❌ Driver não encontrado em: $DRIVER_PATH"
    echo "Execute primeiro: ./Scripts/build_driver.sh"
    exit 1
fi

# Verificar e desinstalar driver antigo usando script dedicado
if [ -d "$INSTALL_PATH" ]; then
    echo "⚠️  Driver MRT Audio antigo detectado - desinstalando primeiro..."
    
    # Chamar script de desinstalação
    SCRIPT_DIR_ABS="$(cd "$SCRIPT_DIR" && pwd)"
    if [ -f "$SCRIPT_DIR_ABS/uninstall_driver.sh" ]; then
        echo "🔄 Executando desinstalação completa..."
        bash "$SCRIPT_DIR_ABS/uninstall_driver.sh"
        echo "✅ Desinstalação concluída"
    else
        # Fallback: desinstalação manual básica
        echo "🗑️  Removendo driver antigo manualmente..."
        pkill -f "coreaudiod" 2>/dev/null || true
        rm -rf "$INSTALL_PATH"
        killall -9 coreaudiod 2>/dev/null || true
        sleep 2
    fi
else
    echo "ℹ️  Nenhum driver MRT Audio anterior encontrado"
fi

# Criar diretório de instalação se não existir
mkdir -p "$(dirname "$INSTALL_PATH")"

# Copiar driver para local de instalação
echo "📋 Copiando driver para sistema..."
cp -R "$DRIVER_PATH" "$INSTALL_PATH"

# Definir permissões corretas
echo "🔒 Configurando permissões..."
chown -R root:wheel "$INSTALL_PATH"
chmod -R 755 "$INSTALL_PATH"

# Reiniciar Core Audio
echo "🔄 Reiniciando Core Audio..."
killall -9 coreaudiod 2>/dev/null || true

# Aguardar reinicialização
sleep 2

echo "✅ Driver MRT Audio instalado com sucesso!"
echo "📍 Localização: $INSTALL_PATH"
echo ""
echo "🔍 Para verificar a instalação:"
echo "   ./Scripts/test_driver.sh"
echo ""
echo "⚠️  Pode ser necessário reiniciar aplicações de áudio para reconhecer o novo driver."