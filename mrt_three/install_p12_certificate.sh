#!/bin/bash

# Script para instalar certificado .p12 e extrair identidade de assinatura

echo "🔐 Instalando certificado .p12 e extraindo identidade..."
echo ""

P12_FILE="/Users/rafaelaredes/Documents/mrt_macos/mrt_three/certificate.p12"

if [ ! -f "$P12_FILE" ]; then
    echo "❌ Arquivo certificate.p12 não encontrado"
    exit 1
fi

echo "✅ Certificado encontrado: $P12_FILE"

# 1. Solicitar senha do certificado (se houver)
echo ""
echo "🔑 O certificado .p12 pode ter uma senha..."
read -s -p "   Digite a senha do certificado (ou ENTER se não tiver): " P12_PASSWORD
echo ""

# 2. Importar certificado para o keychain
echo "📥 Importando certificado para o keychain..."

if [ -z "$P12_PASSWORD" ]; then
    # Sem senha
    security import "$P12_FILE" -k ~/Library/Keychains/login.keychain-db -T /usr/bin/codesign -T /usr/bin/security
else
    # Com senha
    security import "$P12_FILE" -k ~/Library/Keychains/login.keychain-db -P "$P12_PASSWORD" -T /usr/bin/codesign -T /usr/bin/security
fi

if [ $? -eq 0 ]; then
    echo "✅ Certificado importado com sucesso"
else
    echo "❌ Falha ao importar certificado"
    echo "💡 Tente verificar se a senha está correta"
    exit 1
fi

# 3. Verificar certificados agora disponíveis
echo ""
echo "🔍 Verificando certificados disponíveis..."

CERTS=$(security find-identity -v -p codesigning | grep -E "Apple Development|Mac Developer|Developer ID Application")

if [ -n "$CERTS" ]; then
    echo "✅ Certificados de assinatura encontrados:"
    echo "$CERTS"
    echo ""
    
    # Extrair primeiro certificado
    SIGNING_IDENTITY=$(echo "$CERTS" | head -1 | sed 's/.*) "//' | sed 's/".*//')
    echo "🎯 Identidade selecionada: $SIGNING_IDENTITY"
    
    # Salvar para uso
    echo "$SIGNING_IDENTITY" > .signing_identity
    echo "📝 Identidade salva em .signing_identity"
    
    # Mostrar informações detalhadas
    echo ""
    echo "📋 Detalhes do certificado:"
    security find-identity -v -p codesigning | grep "$SIGNING_IDENTITY"
    
    echo ""
    echo "🎉 CERTIFICADO CONFIGURADO COM SUCESSO!"
    echo ""
    echo "🚀 PRÓXIMO PASSO:"
    echo "   Execute: ./setup_real_xpc.sh"
    echo "   Isso irá configurar XPC real com sua assinatura"
    
else
    echo "❌ Nenhum certificado de assinatura encontrado após importação"
    echo ""
    echo "🔍 Certificados encontrados:"
    security find-identity -v -p codesigning
    echo ""
    echo "💡 POSSÍVEIS PROBLEMAS:"
    echo "   • Certificado pode não ser de assinatura de código"
    echo "   • Senha incorreta"
    echo "   • Certificado expirado"
    echo "   • Formato incompatível"
    echo ""
    echo "🔧 SOLUÇÕES:"
    echo "   1. Verifique a senha do certificado"
    echo "   2. Certifique-se de que é um certificado de 'Developer ID' ou 'Apple Development'"
    echo "   3. Tente exportar novamente do Xcode/Developer Portal"
fi