#!/bin/zsh

# Script para configurar o repositório GitHub
REPO_URL="https://github.com/costarafael/mrt-meetingrecordertranscriber.git"

echo "🔄 Configurando integração com GitHub..."

# Verificar se o diretório atual é um repositório Git
if [ ! -d ".git" ]; then
    echo "📦 Inicializando repositório Git..."
    git init
    echo "✅ Repositório Git inicializado"
else
    echo "✅ Repositório Git já inicializado"
fi

# Verificar se o remote já existe
if git remote | grep -q "origin"; then
    echo "⚠️ Remote 'origin' já existe. Atualizando URL..."
    git remote set-url origin $REPO_URL
else
    echo "📡 Adicionando remote 'origin'..."
    git remote add origin $REPO_URL
fi

echo "✅ Remote configurado: $REPO_URL"

# Configurar o branch principal
CURRENT_BRANCH=$(git branch --show-current)
if [ -z "$CURRENT_BRANCH" ]; then
    echo "🔄 Configurando branch principal..."
    git checkout -b main
    echo "✅ Branch 'main' criado"
else
    echo "✅ Branch atual: $CURRENT_BRANCH"
fi

# Adicionar arquivos ao staging
echo "📝 Adicionando arquivos ao staging..."
git add .

# Commit inicial
echo "💾 Realizando commit inicial..."
git commit -m "Configuração inicial do projeto MRT macOS" || echo "⚠️ Nenhuma mudança para commit"

# Criando branches do plano
echo "🔄 Criando branches do plano..."
git checkout -b fase0-preparacao || true
git checkout -b fase1-padronizacao || true

# Retornar ao branch principal
git checkout main

echo "🔄 Tentando push para o repositório remoto..."
git push -u origin main || echo "⚠️ Push falhou. Verifique permissões e credenciais."

echo "🎉 Configuração do GitHub concluída!"
echo ""
echo "Para completar a configuração, você pode precisar:"
echo "1. Configurar suas credenciais do GitHub (se o push falhou)"
echo "2. Executar manualmente: git push -u origin fase0-preparacao fase1-padronizacao"
echo ""
echo "Para verificar o status do repositório: git status" 