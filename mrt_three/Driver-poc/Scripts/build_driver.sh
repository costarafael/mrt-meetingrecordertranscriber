#!/bin/bash

# Script para compilar o driver MRT Audio
# Baseado no BlackHole build system

set -e

echo "🔧 Construindo MRT Audio Driver..."

# Diretórios
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POC_DIR="$(dirname "$SCRIPT_DIR")"
DRIVER_DIR="$POC_DIR/MRTAudioDriver"
BUILD_DIR="$POC_DIR/build"

# Criar diretório de build
mkdir -p "$BUILD_DIR"

# Limpar build anterior
echo "🧹 Limpando builds anteriores..."
rm -rf "$BUILD_DIR"/*

# Build do driver via Xcode
echo "🚀 Compilando driver..."
cd "$DRIVER_DIR"

# Build com xcodebuild
xcodebuild \
    -project MRTAudioDriver.xcodeproj \
    -target BlackHole \
    -configuration Release \
    -arch x86_64 \
    -arch arm64 \
    SYMROOT="$BUILD_DIR" \
    DSTROOT="$BUILD_DIR/dst" \
    OBJROOT="$BUILD_DIR/obj"

# Verificar se o build foi bem-sucedido
if [ -d "$BUILD_DIR/Release/MRTAudioDriver.driver" ]; then
    echo "✅ Driver compilado com sucesso!"
    echo "📍 Localização: $BUILD_DIR/Release/MRTAudioDriver.driver"
    
    # Mostrar informações do driver
    echo ""
    echo "📋 Informações do driver:"
    file "$BUILD_DIR/Release/MRTAudioDriver.driver/Contents/MacOS/MRTAudioDriver"
    
    # Verificar assinatura (se existir)
    echo ""
    echo "🔐 Verificando assinatura:"
    codesign -v "$BUILD_DIR/Release/MRTAudioDriver.driver" 2>/dev/null && echo "✅ Assinado" || echo "❌ Não assinado"
    
elif [ -d "$BUILD_DIR/Release/BlackHole.driver" ]; then
    echo "✅ Driver compilado com sucesso!"
    echo "📍 Localização: $BUILD_DIR/Release/BlackHole.driver"
    
    # Renomear para MRTAudioDriver
    mv "$BUILD_DIR/Release/BlackHole.driver" "$BUILD_DIR/Release/MRTAudioDriver.driver"
    echo "🔄 Renomeado para: $BUILD_DIR/Release/MRTAudioDriver.driver"
    
    # Mostrar informações do driver
    echo ""
    echo "📋 Informações do driver:"
    find "$BUILD_DIR/Release/MRTAudioDriver.driver/Contents/MacOS/" -type f -exec file {} \;
    
    # Verificar assinatura (se existir)
    echo ""
    echo "🔐 Verificando assinatura:"
    codesign -v "$BUILD_DIR/Release/MRTAudioDriver.driver" 2>/dev/null && echo "✅ Assinado" || echo "❌ Não assinado"
    
else
    echo "❌ Erro na compilação do driver!"
    exit 1
fi

echo ""
echo "✨ Build concluído!"
echo "Para instalar: sudo ./Scripts/install_driver.sh"