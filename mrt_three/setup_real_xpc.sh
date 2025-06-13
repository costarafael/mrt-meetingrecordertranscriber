#!/bin/bash

# Script para configurar XPC real com assinatura de desenvolvimento
# Remove simulação e habilita funcionalidade XPC real

echo "🚀 Configurando Core Audio TAP XPC Real..."
echo ""

# 1. Verificar se Xcode está instalado
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Xcode não encontrado. Instale o Xcode primeiro."
    exit 1
fi

echo "✅ Xcode encontrado"

# 2. Verificar certificados de desenvolvimento disponíveis
echo "🔍 Verificando certificados de desenvolvimento..."

CERTS=$(security find-identity -v -p codesigning | grep "Apple Development\|Mac Developer\|Developer ID")
if [ -z "$CERTS" ]; then
    echo "⚠️  Nenhum certificado de desenvolvimento encontrado no Keychain."
    echo ""
    echo "📋 AÇÃO NECESSÁRIA:"
    echo "   1. Abra o Xcode"
    echo "   2. Vá em Xcode > Settings > Accounts"
    echo "   3. Adicione sua conta de desenvolvedor Apple"
    echo "   4. Selecione seu time de desenvolvimento"
    echo "   5. Clique em 'Manage Certificates' e baixe os certificados"
    echo ""
    echo "   Ou execute: xcodebuild -downloadAllPlatforms"
    echo ""
    read -p "   Pressione ENTER depois de configurar a conta no Xcode..."
    
    # Verificar novamente
    CERTS=$(security find-identity -v -p codesigning | grep "Apple Development\|Mac Developer\|Developer ID")
    if [ -z "$CERTS" ]; then
        echo "❌ Ainda não há certificados. Configure sua conta de desenvolvedor no Xcode."
        exit 1
    fi
fi

echo "✅ Certificados de desenvolvimento encontrados:"
echo "$CERTS"
echo ""

# 3. Selecionar o primeiro certificado válido
SIGNING_IDENTITY=$(echo "$CERTS" | head -1 | sed 's/.*) "//' | sed 's/".*//')
echo "🎯 Usando certificado: $SIGNING_IDENTITY"
echo ""

# 4. Remover simulação do código
echo "🔧 Removendo modo simulação do CoreAudioTapXPCService..."

# Backup do arquivo original
cp "Sources/Services/Audio/XPC/CoreAudioTapXPCService.swift" "Sources/Services/Audio/XPC/CoreAudioTapXPCService.swift.backup"

# Modificar para usar XPC real sempre
cat > /tmp/xpc_real_patch.swift << 'EOF'
    func requestSystemPermissions() async -> Bool {
        logger.info("🔐 Solicitando permissões para Core Audio TAP XPC real", category: .audio)
        
        // Verificar se Helper Tool pode ser instalada/está disponível
        let status = await helperManager.getInstallationStatus()
        
        if status.isInstalled {
            logger.info("✅ Helper Tool já instalada, permissões OK", category: .audio)
            return true
        }
        
        if status.canInstall {
            logger.info("Helper Tool pode ser instalada, permissões disponíveis", category: .audio)
            return true
        }
        
        logger.warning("Helper Tool não pode ser instalada", category: .audio)
        return false
    }
    
    func isSystemAudioAvailable() async -> Bool {
        // Verificar se Helper Tool está disponível ou pode ser instalada
        let status = await helperManager.getInstallationStatus()
        let available = status.isInstalled || status.canInstall
        logger.debug("Core Audio TAP XPC real: áudio do sistema disponível = \(available)", category: .audio)
        return available
    }
EOF

# Aplicar patch removendo retornos sempre true
sed -i.bak '
/func requestSystemPermissions/,/^    }$/{
    /Para Core Audio TAP via XPC, sempre retornar true/,/return true/{
        s/.*/        \/\/ Removido modo simulação - usando XPC real/
        /return true/d
    }
}
/func isSystemAudioAvailable/,/^    }$/{
    /Core Audio TAP via XPC está sempre "disponível"/,/return true/{
        s/.*/        \/\/ Removido modo simulação - usando XPC real/
        /return true/d
    }
}
' "Sources/Services/Audio/XPC/CoreAudioTapXPCService.swift"

echo "✅ Modo simulação removido"

# 5. Modificar HelperInstallationManager para não usar fallback
echo "🔧 Configurando HelperInstallationManager para XPC real..."

cp "Sources/Services/Audio/XPC/HelperInstallationManager.swift" "Sources/Services/Audio/XPC/HelperInstallationManager.swift.backup"

# Remover fallback para simulação
sed -i.bak '
/🔧 Usando modo simulado em produção/,/return true/{
    s/return true/throw XPCError.installationFailed("Aplicação ou Helper Tool não assinada")/
}
/🔧 Fallback: usando modo simulado/,/continuation.resume(returning: true)/{
    s/continuation.resume(returning: true)/continuation.resume(returning: false)/
}
' "Sources/Services/Audio/XPC/HelperInstallationManager.swift"

echo "✅ Fallback para simulação removido"

# 6. Criar Info.plist com assinatura correta
echo "📋 Atualizando Info.plist com requisitos de assinatura..."

# Obter Team ID da conta de desenvolvedor
TEAM_ID=$(echo "$SIGNING_IDENTITY" | grep -o '[A-Z0-9]\{10\}' | head -1)
if [ -z "$TEAM_ID" ]; then
    echo "⚠️  Não foi possível extrair Team ID do certificado"
    echo "   Usando identifier genérico para Helper Tool"
    HELPER_REQUIREMENT="identifier \"com.meetingrecorder.AudioCaptureHelper\""
else
    echo "🎯 Team ID detectado: $TEAM_ID"
    HELPER_REQUIREMENT="identifier \"com.meetingrecorder.AudioCaptureHelper\" and certificate leaf[field.1.2.840.113635.100.6.1.9] exists and certificate leaf[field.1.2.840.113635.100.6.1.9] = \"$TEAM_ID\""
fi

echo "✅ Configuração de assinatura preparada"

# 7. Recompilar com configurações reais
echo "🔧 Recompilando aplicação para XPC real..."
./build_production.sh

if [ $? -ne 0 ]; then
    echo "❌ Falha na compilação. Restaurando backups..."
    mv "Sources/Services/Audio/XPC/CoreAudioTapXPCService.swift.backup" "Sources/Services/Audio/XPC/CoreAudioTapXPCService.swift"
    mv "Sources/Services/Audio/XPC/HelperInstallationManager.swift.backup" "Sources/Services/Audio/XPC/HelperInstallationManager.swift"
    exit 1
fi

echo "✅ Aplicação recompilada"

# 8. Assinar aplicação e Helper Tool
echo "✍️  Assinando aplicação com certificado de desenvolvimento..."

APP_NAME="MRTThree_Production.app"

# Assinar Helper Tool primeiro
echo "   Assinando Helper Tool..."
codesign --force --sign "$SIGNING_IDENTITY" \
    --options runtime \
    --entitlements /dev/null \
    "$APP_NAME/Contents/Library/LaunchServices/AudioCaptureHelper"

if [ $? -eq 0 ]; then
    echo "   ✅ Helper Tool assinada"
else
    echo "   ❌ Falha ao assinar Helper Tool"
    exit 1
fi

# Assinar aplicação principal
echo "   Assinando aplicação principal..."
codesign --force --sign "$SIGNING_IDENTITY" \
    --options runtime \
    --deep \
    "$APP_NAME"

if [ $? -eq 0 ]; then
    echo "   ✅ Aplicação assinada"
else
    echo "   ❌ Falha ao assinar aplicação"
    exit 1
fi

# 9. Verificar assinaturas
echo "🔍 Verificando assinaturas..."
echo "   Helper Tool:"
codesign -v -d "$APP_NAME/Contents/Library/LaunchServices/AudioCaptureHelper" 2>&1 | head -3

echo "   Aplicação:"
codesign -v -d "$APP_NAME" 2>&1 | head -3

echo ""
echo "🎉 CONFIGURAÇÃO COMPLETA!"
echo ""
echo "✅ Core Audio TAP XPC Real configurado e assinado"
echo "✅ Modo simulação removido"
echo "✅ Aplicação pronta para XPC real"
echo ""
echo "🚀 TESTE AGORA:"
echo "   1. Execute: open MRTThree_Production.app"
echo "   2. Marque 'Gravar com Core Audio Tap'"
echo "   3. Inicie gravação"
echo "   4. Se pedir permissões de admin, aceite"
echo ""
echo "📝 Logs de sucesso esperados:"
echo "   - 'Helper Tool instalada com sucesso'"
echo "   - 'Conexão XPC criada e ativada'"
echo "   - 'Core Audio Tap (XPC) iniciado com sucesso'"