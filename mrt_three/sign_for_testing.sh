#!/bin/bash

# Script para assinar a aplicação para teste
# Usa assinatura self-signed para desenvolvimento

echo "✍️  Assinando aplicação para teste de XPC..."
echo ""

APP_NAME="MRTThree_Production.app"

if [ ! -d "$APP_NAME" ]; then
    echo "❌ Bundle não encontrado. Execute primeiro: ./build_production.sh"
    exit 1
fi

# Verificar se há certificados de desenvolvimento disponíveis
echo "🔍 Verificando certificados disponíveis..."
CERT_COUNT=$(security find-identity -v -p codesigning | grep "Mac Developer\|Apple Development\|Developer ID Application" | wc -l)

if [ $CERT_COUNT -eq 0 ]; then
    echo "⚠️  Nenhum certificado de desenvolvimento encontrado."
    echo "   Criando certificado self-signed para teste..."
    
    # Criar certificado self-signed para teste
    CERT_NAME="MRTThree Development"
    
    # Verificar se já existe
    if security find-identity -v -p codesigning | grep -q "$CERT_NAME"; then
        echo "✅ Certificado $CERT_NAME já existe"
    else
        echo "🔧 Criando certificado self-signed..."
        # Criar certificado temporário para desenvolvimento
        cat > /tmp/cert_config.cnf << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = $CERT_NAME
O = Development
C = US

[v3_req]
keyUsage = digitalSignature
extendedKeyUsage = codeSigning
EOF
        
        # Gerar chave e certificado
        openssl req -x509 -newkey rsa:2048 -keyout /tmp/cert_key.pem -out /tmp/cert.pem -days 365 -nodes -config /tmp/cert_config.cnf
        
        # Criar arquivo p12
        openssl pkcs12 -export -out /tmp/cert.p12 -inkey /tmp/cert_key.pem -in /tmp/cert.pem -password pass:
        
        # Importar para keychain
        security import /tmp/cert.p12 -k ~/Library/Keychains/login.keychain-db -P ""
        
        # Limpar arquivos temporários
        rm -f /tmp/cert_config.cnf /tmp/cert_key.pem /tmp/cert.pem /tmp/cert.p12
        
        echo "✅ Certificado self-signed criado"
    fi
    
    SIGNING_IDENTITY="$CERT_NAME"
else
    # Usar primeiro certificado de desenvolvimento encontrado
    SIGNING_IDENTITY=$(security find-identity -v -p codesigning | grep "Mac Developer\|Apple Development\|Developer ID Application" | head -1 | sed 's/.*) "//' | sed 's/".*//')
    echo "✅ Usando certificado: $SIGNING_IDENTITY"
fi

echo ""
echo "✍️  Assinando Helper Tool..."
codesign --force --sign "$SIGNING_IDENTITY" "$APP_NAME/Contents/Library/LaunchServices/AudioCaptureHelper"

if [ $? -eq 0 ]; then
    echo "✅ Helper Tool assinada"
else
    echo "❌ Falha ao assinar Helper Tool"
fi

echo ""
echo "✍️  Assinando aplicação principal..."
codesign --force --sign "$SIGNING_IDENTITY" --deep "$APP_NAME"

if [ $? -eq 0 ]; then
    echo "✅ Aplicação assinada"
else
    echo "❌ Falha ao assinar aplicação"
fi

echo ""
echo "🔍 Verificando assinaturas..."
echo "Helper Tool:"
codesign -v "$APP_NAME/Contents/Library/LaunchServices/AudioCaptureHelper" 2>&1 | head -3

echo "Aplicação:"
codesign -v "$APP_NAME" 2>&1 | head -3

echo ""
echo "✅ Processo de assinatura concluído!"
echo ""
echo "🎯 Agora execute: ./test_production.sh"
echo "   Com assinatura, o XPC tem mais chances de funcionar."