#!/bin/bash

# Script simplificado para configurar XPC real

echo "🚀 Configurando Core Audio TAP XPC Real..."
echo ""

# 1. Backup e restaurar arquivos limpos primeiro
echo "🔄 Restaurando arquivos limpos..."

if [ -f "Sources/Services/Audio/XPC/CoreAudioTapXPCService.swift.backup" ]; then
    cp "Sources/Services/Audio/XPC/CoreAudioTapXPCService.swift.backup" "Sources/Services/Audio/XPC/CoreAudioTapXPCService.swift"
fi

if [ -f "Sources/Services/Audio/XPC/HelperInstallationManager.swift.backup" ]; then
    cp "Sources/Services/Audio/XPC/HelperInstallationManager.swift.backup" "Sources/Services/Audio/XPC/HelperInstallationManager.swift"
fi

# 2. Remover simulação do CoreAudioTapXPCService
echo "🔧 Modificando CoreAudioTapXPCService para XPC real..."

cat > /tmp/fix_xpc_service.swift << 'EOF'
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

# Substituir funções específicas
sed -i.bak '
/func requestSystemPermissions() async -> Bool {/,/^    }$/{
    /Para Core Audio TAP via XPC, sempre retornar true/,/return true/ {
        r /tmp/fix_xpc_service.swift
        d
    }
    /✅ Core Audio TAP XPC: permissões sempre disponíveis/d
    /return true/d
}
/func isSystemAudioAvailable() async -> Bool {/,/^    }$/{
    /Core Audio TAP via XPC está sempre "disponível"/,/return true/ {
        d
    }
}
' "Sources/Services/Audio/XPC/CoreAudioTapXPCService.swift"

echo "✅ CoreAudioTapXPCService modificado"

# 3. Remover fallbacks do HelperInstallationManager
echo "🔧 Modificando HelperInstallationManager para XPC real..."

sed -i.bak2 '
/🔧 Usando modo simulado em produção devido à falta de assinatura/,/return true/ {
    s/return true/throw XPCError.installationFailed("Aplicação não assinada adequadamente")/
}
/🔧 Usando modo simulado em produção devido à Helper Tool não assinada/,/return true/ {
    s/return true/throw XPCError.installationFailed("Helper Tool não assinada adequadamente")/
}
/🔧 Fallback: usando modo simulado devido à falha do SMJobBless/,/continuation.resume(returning: true)/ {
    s/continuation.resume(returning: true)/continuation.resume(returning: false)/
}
/🔧 Fallback: usando modo simulado devido ao erro/,/continuation.resume(returning: true)/ {
    s/continuation.resume(returning: true)/continuation.resume(returning: false)/
}
' "Sources/Services/Audio/XPC/HelperInstallationManager.swift"

echo "✅ HelperInstallationManager modificado"

# 4. Recompilar
echo "🔧 Recompilando aplicação..."
./build_production.sh

if [ $? -ne 0 ]; then
    echo "❌ Falha na compilação"
    exit 1
fi

echo "✅ Aplicação recompilada"

# 5. Assinar com ad-hoc
echo "✍️  Assinando com assinatura ad-hoc..."

APP_NAME="MRTThree_Production.app"

# Assinar Helper Tool
codesign --force --sign "-" --options runtime "$APP_NAME/Contents/Library/LaunchServices/AudioCaptureHelper"
echo "✅ Helper Tool assinada"

# Assinar aplicação
codesign --force --sign "-" --options runtime --deep "$APP_NAME"
echo "✅ Aplicação assinada"

# 6. Verificar
echo "🔍 Verificando assinaturas..."
codesign -v "$APP_NAME/Contents/Library/LaunchServices/AudioCaptureHelper" 2>&1 | head -1
codesign -v "$APP_NAME" 2>&1 | head -1

# Limpar temporários
rm -f /tmp/fix_xpc_service.swift

echo ""
echo "🎉 CONFIGURAÇÃO COMPLETA!"
echo ""
echo "✅ Core Audio TAP XPC Real configurado"
echo "✅ Modo simulação removido"
echo "✅ Aplicação assinada (ad-hoc)"
echo ""
echo "🚀 TESTE AGORA:"
echo "   open MRTThree_Production.app"
echo ""
echo "⚠️  IMPORTANTE:"
echo "   • Marque 'Gravar com Core Audio Tap'"
echo "   • Se pedir senha de admin, forneça"
echo "   • XPC real pode ter limitações com assinatura ad-hoc"