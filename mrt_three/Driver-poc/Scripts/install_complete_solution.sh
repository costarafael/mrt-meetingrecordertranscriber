#!/bin/bash

# =============================================================================
# SOLUÇÃO DEFINITIVA COMPLETA - Instalação Automática MRT Audio
# Replica comportamento do Krisp/Teams: ZERO configuração manual
# =============================================================================

echo "🎯 MRT AUDIO - SOLUÇÃO DEFINITIVA COMPLETA"
echo "=========================================="

echo ""
echo "💡 ARQUITETURA CORRETA (como Krisp/Teams):"
echo "- Driver MRTAudio = Loopback para captura"
echo "- Multi-Output Device = Speakers + Captura"
echo "- Configuração 100% automática"
echo "- ZERO interação manual necessária"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 1. INSTALAR DRIVER
echo "📦 ETAPA 1: Instalando Driver MRTAudio..."
echo "========================================="

if [ "$EUID" -ne 0 ]; then
    echo "🔐 Solicitando permissões de administrador para instalar driver..."
    sudo "$SCRIPT_DIR/install_driver.sh"
else
    "$SCRIPT_DIR/install_driver.sh"
fi

if [ $? -ne 0 ]; then
    echo "❌ Erro ao instalar driver"
    exit 1
fi

echo "✅ Driver MRTAudio instalado com sucesso"

# 2. COMPILAR GERENCIADOR AUTOMÁTICO
echo ""
echo "🔧 ETAPA 2: Compilando Gerenciador Automático..."
echo "==============================================="

cd "$PROJECT_ROOT/MRTAudioSetup"

if [ ! -f "Package.swift" ]; then
    echo "❌ Package.swift não encontrado"
    exit 1
fi

echo "🚀 Compilando MRTAudioSetup..."
swift build -c release

if [ $? -ne 0 ]; then
    echo "❌ Erro ao compilar MRTAudioSetup"
    exit 1
fi

echo "✅ MRTAudioSetup compilado com sucesso"

# 3. CONFIGURAR AUTOMATICAMENTE
echo ""
echo "⚡ ETAPA 3: Configuração Automática..."
echo "====================================="

EXECUTABLE_PATH="$PROJECT_ROOT/MRTAudioSetup/.build/release/MRTAudioSetup"

if [ ! -f "$EXECUTABLE_PATH" ]; then
    echo "❌ Executável não encontrado: $EXECUTABLE_PATH"
    exit 1
fi

echo "🎯 Executando configuração automática..."
"$EXECUTABLE_PATH"

if [ $? -ne 0 ]; then
    echo "❌ Erro na configuração automática"
    exit 1
fi

# 4. CRIAR ATALHOS CONVENIENTES
echo ""
echo "🔗 ETAPA 4: Criando Atalhos Convenientes..."
echo "==========================================="

# Criar symlink para fácil acesso
SYMLINK_PATH="/usr/local/bin/mrtaudio"

if [ -L "$SYMLINK_PATH" ]; then
    sudo rm "$SYMLINK_PATH"
fi

sudo ln -s "$EXECUTABLE_PATH" "$SYMLINK_PATH"

if [ $? -eq 0 ]; then
    echo "✅ Atalho criado: mrtaudio"
else
    echo "⚠️  Não foi possível criar atalho (opcional)"
fi

# Criar script de desktop (opcional)
DESKTOP_SCRIPT="$HOME/Desktop/MRT Audio Manager.command"
cat > "$DESKTOP_SCRIPT" << EOF
#!/bin/bash
cd "\$(dirname "\$0")"
"$EXECUTABLE_PATH" --status
echo ""
echo "Comandos disponíveis:"
echo "  mrtaudio         # Ver status"
echo "  mrtaudio --help  # Ajuda completa"
echo ""
read -p "Pressione ENTER para fechar..."
EOF

chmod +x "$DESKTOP_SCRIPT"
echo "✅ Script de desktop criado"

# 5. VERIFICAÇÃO FINAL
echo ""
echo "🔍 ETAPA 5: Verificação Final..."
echo "==============================="

"$EXECUTABLE_PATH" --status

echo ""
echo "🎯 INSTALAÇÃO COMPLETA FINALIZADA!"
echo "=================================="
echo ""
echo "✅ SOLUÇÃO DEFINITIVA ATIVA:"
echo ""
echo "📱 Driver MRTAudio: Instalado e funcionando"
echo "🔊 Multi-Output Device: Criado automaticamente"
echo "🎧 Áudio: Funciona normalmente + captura simultânea"
echo "⚙️  Configuração: 100% automática (como Krisp/Teams)"
echo ""
echo "🎮 COMANDOS DISPONÍVEIS:"
echo "========================"
echo ""
echo "  mrtaudio              # Ver status atual"
echo "  mrtaudio --disable    # Desativar temporariamente" 
echo "  mrtaudio --help       # Ajuda completa"
echo ""
echo "  $EXECUTABLE_PATH      # Caminho completo"
echo ""
echo "🚀 PRONTO PARA USO!"
echo "=================="
echo ""
echo "🎯 Como funciona agora:"
echo "1. Áudio reproduz normalmente nos speakers"
echo "2. Aplicação pode capturar via MRTAudio simultaneamente"
echo "3. Sem necessidade de configuração manual"
echo "4. Comportamento idêntico ao Krisp/Microsoft Teams"
echo ""
echo "💡 Para testar: Reproduza qualquer áudio - você ouvirá"
echo "   normalmente E a captura estará disponível via MRTAudio"