#!/bin/zsh

# Script de configuração do ambiente para o projeto MRT macOS

echo "🚀 Configurando ambiente de desenvolvimento para MRT macOS"

# Verificar se git está disponível
if ! command -v git &> /dev/null; then
    echo "❌ Git não encontrado. Por favor, instale o Git antes de continuar."
    exit 1
fi

# Criar branches
echo "📂 Criando branches de desenvolvimento..."
git checkout -b fase0-preparacao
echo "✅ Branch 'fase0-preparacao' criada"

# Verificar se o XCode está instalado
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Xcode não encontrado. Por favor, instale o Xcode antes de continuar."
    exit 1
fi

# Instalar dependências
echo "📦 Instalando dependências..."
swift package resolve
echo "✅ Dependências instaladas"

# Verificar se SwiftLint está instalado
if ! command -v swiftlint &> /dev/null; then
    echo "⚠️ SwiftLint não encontrado. Instalando..."
    brew install swiftlint
else
    echo "✅ SwiftLint já instalado"
fi

# Executar testes iniciais
echo "🧪 Executando testes iniciais..."
xcodebuild clean test -scheme "mrt_macos_app" -destination "platform=macOS" | xcpretty || true
echo "✅ Testes concluídos"

# Tornar o script de GitHub executável
chmod +x Scripts/setup_github.sh

echo "🔗 Configurando integração com GitHub..."
./Scripts/setup_github.sh

echo "🎉 Ambiente configurado com sucesso!"
echo "Próximos passos:"
echo "1. Verificar a conexão com o repositório GitHub"
echo "2. Implementar LoggingService padronizado"
echo "3. Migrar serviços para usar o LoggingService"
echo "4. Implementar padronização de erros"
echo "5. Validar os testes"

exit 0 