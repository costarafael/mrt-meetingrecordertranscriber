#!/bin/bash

# Script para configurar XPC real usando assinatura ad-hoc
# Funciona sem certificado de desenvolvedor para teste local

echo "🚀 Configurando Core Audio TAP XPC Real (Assinatura Ad-Hoc)..."
echo ""

echo "⚠️  IMPORTANTE: Assinatura ad-hoc permite teste local,"
echo "   mas pode ter limitações com XPC privilegiado."
echo ""
read -p "   Continuar? (y/n): " CONTINUE

if [ "$CONTINUE" != "y" ] && [ "$CONTINUE" != "Y" ]; then
    echo "❌ Cancelado pelo usuário"
    exit 1
fi

# 1. Remover simulação do código
echo "🔧 Removendo modo simulação do CoreAudioTapXPCService..."

# Backup
cp "Sources/Services/Audio/XPC/CoreAudioTapXPCService.swift" "Sources/Services/Audio/XPC/CoreAudioTapXPCService.swift.backup"

# Editar o arquivo para remover simulação
cat > /tmp/xpc_real_patch.sed << 'EOF'
/func requestSystemPermissions.*async -> Bool {/,/^    }$/{
    /Para Core Audio TAP via XPC, sempre retornar true/,/return true/{
        c\
        // Verificar se Helper Tool pode ser instalada/está disponível\
        let status = await helperManager.getInstallationStatus()\
        \
        if status.isInstalled {\
            logger.info("✅ Helper Tool já instalada, permissões OK", category: .audio)\
            return true\
        }\
        \
        if status.canInstall {\
            logger.info("Helper Tool pode ser instalada, permissões disponíveis", category: .audio)\
            return true\
        }\
        \
        logger.warning("Helper Tool não pode ser instalada", category: .audio)\
        return false
    }
}
/func isSystemAudioAvailable.*async -> Bool {/,/^    }$/{
    /Core Audio TAP via XPC está sempre "disponível"/,/return true/{
        c\
        // Verificar se Helper Tool está disponível ou pode ser instalada\
        let status = await helperManager.getInstallationStatus()\
        let available = status.isInstalled || status.canInstall\
        logger.debug("Core Audio TAP XPC real: áudio do sistema disponível = \\(available)", category: .audio)\
        return available
    }
}
EOF

sed -f /tmp/xpc_real_patch.sed "Sources/Services/Audio/XPC/CoreAudioTapXPCService.swift" > /tmp/xpc_service_fixed.swift
mv /tmp/xpc_service_fixed.swift "Sources/Services/Audio/XPC/CoreAudioTapXPCService.swift"

echo "✅ Modo simulação removido"

# 2. Modificar HelperInstallationManager para não usar fallback
echo "🔧 Configurando HelperInstallationManager para XPC real..."

cp "Sources/Services/Audio/XPC/HelperInstallationManager.swift" "Sources/Services/Audio/XPC/HelperInstallationManager.swift.backup"

# Remover fallbacks para simulação
sed -i.bak '
/🔧 Usando modo simulado em produção/,/return true/{
    s/return true/throw XPCError.installationFailed("Aplicação ou Helper Tool não assinada adequadamente")/
}
/🔧 Fallback: usando modo simulado/,/continuation.resume(returning: true)/{
    s/continuation.resume(returning: true)/continuation.resume(returning: false)/
}
' "Sources/Services/Audio/XPC/HelperInstallationManager.swift"

echo "✅ Fallback para simulação removido"

# 3. Recompilar aplicação
echo "🔧 Recompilando aplicação..."
./build_production.sh

if [ $? -ne 0 ]; then
    echo "❌ Falha na compilação. Restaurando backups..."
    mv "Sources/Services/Audio/XPC/CoreAudioTapXPCService.swift.backup" "Sources/Services/Audio/XPC/CoreAudioTapXPCService.swift"
    mv "Sources/Services/Audio/XPC/HelperInstallationManager.swift.backup" "Sources/Services/Audio/XPC/HelperInstallationManager.swift"
    exit 1
fi

echo "✅ Aplicação recompilada"

# 4. Assinar com assinatura ad-hoc
echo "✍️  Aplicando assinatura ad-hoc..."

APP_NAME="MRTThree_Production.app"

# Assinar Helper Tool
echo "   Assinando Helper Tool..."
codesign --force --sign "-" \
    --options runtime \
    "$APP_NAME/Contents/Library/LaunchServices/AudioCaptureHelper"

if [ $? -eq 0 ]; then
    echo "   ✅ Helper Tool assinada (ad-hoc)"
else
    echo "   ❌ Falha ao assinar Helper Tool"
    exit 1
fi

# Assinar aplicação principal
echo "   Assinando aplicação principal..."
codesign --force --sign "-" \
    --options runtime \
    --deep \
    "$APP_NAME"

if [ $? -eq 0 ]; then
    echo "   ✅ Aplicação assinada (ad-hoc)"
else
    echo "   ❌ Falha ao assinar aplicação"
    exit 1
fi

# 5. Verificar assinaturas
echo "🔍 Verificando assinaturas..."
echo "   Helper Tool:"
codesign -d -v "$APP_NAME/Contents/Library/LaunchServices/AudioCaptureHelper" 2>&1 | head -3

echo "   Aplicação:"
codesign -d -v "$APP_NAME" 2>&1 | head -3

# 6. Criar entitlements file para Helper Tool (necessário para XPC)
echo "📋 Criando entitlements para Helper Tool..."

cat > /tmp/helper_entitlements.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.private.tcc.allow</key>
    <array>
        <string>kTCCServiceMicrophone</string>
        <string>kTCCServiceScreenCapture</string>
    </array>
</dict>
</plist>
EOF

# Re-assinar Helper Tool com entitlements
echo "   Re-assinando Helper Tool com entitlements..."
codesign --force --sign "-" \
    --entitlements /tmp/helper_entitlements.plist \
    "$APP_NAME/Contents/Library/LaunchServices/AudioCaptureHelper"

echo "✅ Helper Tool assinada com entitlements"

echo ""
echo "🎉 CONFIGURAÇÃO COMPLETA!"
echo ""
echo "✅ Core Audio TAP XPC Real configurado (assinatura ad-hoc)"
echo "✅ Modo simulação removido"
echo "✅ Aplicação assinada para teste local"
echo ""
echo "⚠️  LIMITAÇÕES DA ASSINATURA AD-HOC:"
echo "   • XPC privilegiado pode ser restrito"
echo "   • Pode necessitar permissões de administrador"
echo "   • Funciona para teste local, mas não para distribuição"
echo ""
echo "🚀 TESTE AGORA:"
echo "   1. Execute: open MRTThree_Production.app"
echo "   2. Marque 'Gravar com Core Audio Tap'"
echo "   3. Inicie gravação"
echo "   4. Se pedir senha de administrador, forneça"
echo ""
echo "📝 Logs esperados (sucesso):"
echo "   - 'Helper Tool instalada com sucesso'"
echo "   - 'Conexão XPC criada e ativada'"
echo "   - 'Core Audio Tap (XPC) iniciado com sucesso'"
echo ""
echo "📝 Se XPC falhar:"
echo "   - Logs mostrarão falhas específicas de instalação"
echo "   - Isso é normal com assinatura ad-hoc"
echo "   - Configure certificado de desenvolvedor para XPC completo"

# Limpar arquivos temporários
rm -f /tmp/xpc_real_patch.sed /tmp/helper_entitlements.plist