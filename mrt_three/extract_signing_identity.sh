#!/bin/bash

# Script para extrair assinatura de desenvolvimento do Xcode

echo "🔍 Extraindo assinatura de desenvolvimento do Xcode..."
echo ""

# 1. Verificar se há projeto temporário aberto no Xcode
echo "📋 Instruções para garantir que certificados foram criados:"
echo ""
echo "1. Abra seu projeto temporário no Xcode"
echo "2. Selecione o target principal"
echo "3. Vá para 'Signing & Capabilities'"
echo "4. Marque 'Automatically manage signing'"
echo "5. Selecione seu Team (Apple ID)"
echo "6. Build o projeto (Cmd+B)"
echo ""
read -p "✅ Pressione ENTER após fazer build do projeto no Xcode..."

# 2. Verificar certificados agora
echo "🔍 Procurando certificados de desenvolvimento..."

# Verificar em múltiplos keychains
ALL_KEYCHAINS=$(security list-keychains | tr -d '"' | xargs)

for keychain in $ALL_KEYCHAINS; do
    echo "   Verificando keychain: $keychain"
    CERTS=$(security find-identity -v -p codesigning "$keychain" 2>/dev/null | grep -E "Apple Development|Mac Developer|Developer ID Application")
    
    if [ -n "$CERTS" ]; then
        echo "✅ Certificados encontrados em $keychain:"
        echo "$CERTS"
        
        # Extrair o primeiro certificado válido
        SIGNING_IDENTITY=$(echo "$CERTS" | head -1 | sed 's/.*) "//' | sed 's/".*//')
        echo ""
        echo "🎯 Selecionado: $SIGNING_IDENTITY"
        
        # Salvar para uso posterior
        echo "$SIGNING_IDENTITY" > .signing_identity
        echo "📝 Identidade salva em .signing_identity"
        
        # Extrair informações adicionais
        CERT_DETAILS=$(security find-identity -v -p codesigning "$keychain" | grep "$SIGNING_IDENTITY")
        echo "📋 Detalhes: $CERT_DETAILS"
        
        exit 0
    fi
done

# 3. Se não encontrou, tentar métodos alternativos
echo "❌ Nenhum certificado encontrado nos keychains."
echo ""
echo "🔧 Tentando métodos alternativos..."

# Verificar se xcodebuild consegue ver certificados
echo "   Testando via xcodebuild..."
TEMP_DIR="/tmp/CodeSignTest"
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

cd "$TEMP_DIR"

# Criar projeto mínimo
cat > main.swift << 'EOF'
import Foundation
print("Test")
EOF

cat > Package.swift << 'EOF'
// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "CodeSignTest",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "CodeSignTest", path: ".")
    ]
)
EOF

# Tentar build com assinatura automática
echo "   Tentando build com Swift Package Manager..."
swift build 2>/dev/null >/dev/null

# Voltar ao diretório original
cd - >/dev/null
rm -rf "$TEMP_DIR"

# 4. Sugerir soluções manuais
echo ""
echo "💡 SOLUÇÕES ALTERNATIVAS:"
echo ""
echo "OPÇÃO 1 - Verificar manualmente no Keychain:"
echo "   1. Abra 'Keychain Access'"
echo "   2. Procure por 'Developer ID' ou 'Apple Development'"
echo "   3. Copie o nome exato do certificado"
echo "   4. Cole aqui: "
read -p "      Certificado: " MANUAL_CERT

if [ -n "$MANUAL_CERT" ]; then
    echo "$MANUAL_CERT" > .signing_identity
    echo "✅ Certificado manual salvo: $MANUAL_CERT"
    exit 0
fi

echo ""
echo "OPÇÃO 2 - Criar certificado ad-hoc para teste:"
echo "   Vamos criar um certificado temporário para teste"
read -p "   Continuar? (y/n): " CREATE_ADHOC

if [ "$CREATE_ADHOC" = "y" ] || [ "$CREATE_ADHOC" = "Y" ]; then
    echo "🔧 Criando certificado ad-hoc..."
    
    # Usar assinatura ad-hoc
    echo "-" > .signing_identity
    echo "✅ Configurado para assinatura ad-hoc"
    echo ""
    echo "⚠️  NOTA: Assinatura ad-hoc permite teste local mas XPC pode não funcionar completamente"
    exit 0
fi

echo ""
echo "❌ Não foi possível extrair certificado de assinatura."
echo ""
echo "🔄 TENTE NOVAMENTE:"
echo "   1. Configure sua conta de desenvolvedor no Xcode"
echo "   2. Crie um projeto simples macOS"
echo "   3. Faça build com assinatura automática ativa"
echo "   4. Execute este script novamente"