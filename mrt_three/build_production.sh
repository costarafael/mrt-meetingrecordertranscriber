#!/bin/bash

# Script para build de produção com XPC real
# Cria bundle .app com Helper Tool embarcada

set -e

echo "🚀 Building MRT_Three para produção com Core Audio TAP real..."
echo "📍 Diretório: $(pwd)"
echo ""

# Limpar builds anteriores
echo "🧹 Limpando builds anteriores..."
rm -rf .build/production
rm -rf MRTThree.app
rm -rf MRTThree_Production.app

# Compilar Helper Tool
echo "🔧 Compilando Helper Tool..."
cd HelperTools/AudioCaptureHelper

if [ ! -f "AudioCaptureHelper" ]; then
    clang -framework Foundation -framework CoreAudio -framework AudioToolbox -framework Security -o AudioCaptureHelper main.m AudioCaptureService.m
    if [ $? -ne 0 ]; then
        echo "❌ Falha na compilação da Helper Tool."
        exit 1
    fi
fi

cd ../..
echo "✅ Helper Tool compilada"

# Compilar aplicação principal
echo "🔧 Compilando aplicação principal..."
swift build --configuration release

if [ $? -ne 0 ]; then
    echo "❌ Falha na compilação da aplicação."
    exit 1
fi

echo "✅ Aplicação compilada"

# Criar estrutura do bundle .app
echo "📦 Criando bundle .app..."

APP_NAME="MRTThree_Production.app"
CONTENTS_DIR="$APP_NAME/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
LAUNCHSERVICES_DIR="$CONTENTS_DIR/Library/LaunchServices"

mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"
mkdir -p "$LAUNCHSERVICES_DIR"

# Copiar executável principal
echo "📋 Copiando executável principal..."
cp ".build/arm64-apple-macosx/release/MacOSApp" "$MACOS_DIR/MRTThree"

# Copiar Helper Tool
echo "📋 Copiando Helper Tool..."
cp "HelperTools/AudioCaptureHelper/AudioCaptureHelper" "$LAUNCHSERVICES_DIR/"

# Criar Info.plist principal
echo "📋 Criando Info.plist..."
cat > "$CONTENTS_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MRTThree</string>
    <key>CFBundleIdentifier</key>
    <string>com.meetingrecorder.MRTThree</string>
    <key>CFBundleName</key>
    <string>Meeting Recorder Three</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>Esta aplicação precisa acessar o microfone para gravar reuniões.</string>
    <key>NSScreenCaptureDescription</key>
    <string>Esta aplicação precisa capturar a tela para gravar áudio do sistema.</string>
    <key>SMPrivilegedExecutables</key>
    <dict>
        <key>com.meetingrecorder.AudioCaptureHelper</key>
        <string>identifier "com.meetingrecorder.AudioCaptureHelper" and certificate leaf[subject.CN] = "Meeting Recorder Helper"</string>
    </dict>
</dict>
</plist>
EOF

# Definir permissões corretas
echo "🔐 Configurando permissões..."
chmod +x "$MACOS_DIR/MRTThree"
chmod +x "$LAUNCHSERVICES_DIR/AudioCaptureHelper"

# Verificar estrutura criada
echo ""
echo "📋 Estrutura criada:"
find "$APP_NAME" -type f -exec ls -la {} \;

echo ""
echo "✅ Bundle .app criado com sucesso!"
echo "📍 Localização: $(pwd)/$APP_NAME"
echo ""
echo "🎯 Para testar:"
echo "   1. Execute: ./test_production.sh"
echo "   2. Ou abra: open $APP_NAME"
echo ""
echo "⚠️  NOTA: Para funcionar completamente, a aplicação precisa ser"
echo "   assinada com certificado Developer ID. Sem assinatura,"
echo "   o XPC pode falhar e usar modo simulado."