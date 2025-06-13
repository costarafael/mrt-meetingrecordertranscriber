# MRT Audio Driver POC

Este é um Proof of Concept (POC) de um driver de áudio virtual para macOS baseado no BlackHole, desenvolvido para o projeto MRT (Meeting Recording Tool).

## Objetivo

Criar um driver de áudio virtual que:
- ✅ Capture áudio do sistema (loopback)
- ✅ Roteie simultaneamente para saída padrão do usuário
- ✅ Funcione com instalação simplificada
- ⏳ Suporte mudança dinâmica de dispositivos de saída

## Estrutura do Projeto

```
Driver-poc/
├── MRTAudioDriver/          # Driver de áudio baseado no BlackHole
│   ├── MRTAudioDriver.c     # Código principal do driver em C
│   ├── MRTAudioDriver.plist # Configuração do bundle
│   └── MRTAudioDriver.xcodeproj/
├── ControlApp/              # Aplicação Swift de controle
│   ├── Sources/
│   │   ├── main.swift
│   │   └── AudioDriverManager.swift
│   └── Package.swift
├── Scripts/                 # Scripts de build e instalação
│   ├── build_driver.sh      # Compilar driver
│   ├── install_driver.sh    # Instalar driver (requer sudo)
│   ├── test_driver.sh       # Testar instalação
│   └── uninstall_driver.sh  # Remover driver (requer sudo)
├── Documentation/           # Documentação adicional
├── Tests/                   # Testes futuros
└── BlackHole-Reference/     # Código de referência do BlackHole
```

## Quick Start

### 1. Compilar o Driver

```bash
cd Driver-poc
./Scripts/build_driver.sh
```

### 2. Instalar o Driver

```bash
sudo ./Scripts/install_driver.sh
```

### 3. Testar a Instalação

```bash
./Scripts/test_driver.sh
```

### 4. Verificar no Sistema

- Abra **Audio MIDI Setup** (`/Applications/Utilities/`)
- Procure por dispositivos **MRTAudio**
- O driver deve aparecer como dispositivo de entrada e saída

## Status da POC

### ✅ Implementado

- [x] Estrutura base do driver customizada do BlackHole
- [x] Renomeação para MRT Audio Driver
- [x] Sistema de build automatizado
- [x] Scripts de instalação/desinstalação
- [x] Aplicação Swift de controle e monitoramento
- [x] Verificação programática do status do driver

### ⏳ Em Desenvolvimento

- [ ] Funcionalidade de passthrough para saída padrão
- [ ] Roteamento dinâmico para diferentes dispositivos
- [ ] Interface gráfica para controle
- [ ] Instalação via System Extension (para distribuição)

### 🔮 Próximos Passos

- [ ] Implementar captura de áudio do sistema
- [ ] Adicionar roteamento automático para saída padrão
- [ ] Migrar de HAL Plugin para AudioDriverKit/System Extension
- [ ] Criar instalador com menos interação do usuário
- [ ] Testes de performance e latência

## Tecnologias Utilizadas

- **Driver**: C, Core Audio HAL Plugin
- **Aplicação de Controle**: Swift, Core Audio APIs
- **Build System**: Xcode, shell scripts
- **Base**: BlackHole audio loopback driver

## Diferenças do BlackHole Original

1. **Nome/Identidade**: Rebrandado para MRT Audio
2. **Bundle ID**: `com.mrt.audio.driver`
3. **Objetivo**: Foco em recording + passthrough (não apenas loopback)
4. **Controle**: Aplicação Swift integrada para gerenciamento

## Requisitos

- macOS 10.10+ (compatibilidade do BlackHole)
- Xcode Command Line Tools
- Swift 5.7+
- Permissões de administrador para instalação

## Limitações Atuais

1. **Ainda é HAL Plugin**: Não migrado para AudioDriverKit/System Extension
2. **Sem Passthrough**: Funciona apenas como loopback (como BlackHole original)
3. **Instalação Manual**: Requer sudo e reinício do Core Audio
4. **Sem Assinatura**: Driver não assinado (apenas para desenvolvimento)

## Teste de Funcionamento

### Via Aplicação de Controle

```bash
./Scripts/test_driver.sh
```

### Via Audio MIDI Setup

1. Abra Audio MIDI Setup
2. Procure "MRTAudio" nos dispositivos
3. Configure como entrada/saída para testar

### Via Linha de Comando

```bash
# Listar todos os dispositivos de áudio
system_profiler SPAudioDataType

# Verificar se driver está ativo
./ControlApp/.build/release/MRTDriverControl
```

## Troubleshooting

### Driver não aparece após instalação

```bash
# Reiniciar Core Audio
sudo killall -9 coreaudiod

# Verificar se arquivo foi instalado
ls -la /Library/Audio/Plug-Ins/HAL/
```

### Erro de permissões

```bash
# Verificar permissões do driver
ls -la /Library/Audio/Plug-Ins/HAL/MRTAudioDriver.driver/

# Corrigir permissões se necessário
sudo chown -R root:wheel /Library/Audio/Plug-Ins/HAL/MRTAudioDriver.driver/
sudo chmod -R 755 /Library/Audio/Plug-Ins/HAL/MRTAudioDriver.driver/
```

### Desinstalar completamente

```bash
sudo ./Scripts/uninstall_driver.sh
```

## Contribuição para o Projeto Principal

Esta POC serve como base para:

1. **Entendimento da arquitetura** de drivers de áudio no macOS
2. **Validação do conceito** de dual functionality (capture + passthrough)
3. **Processo de build e distribuição** de drivers de áudio
4. **Integração com aplicação principal** do MRT

Os aprendizados desta POC serão aplicados na implementação final usando AudioDriverKit e System Extensions para uma solução mais moderna e segura.

---

**Nota**: Esta é uma POC para desenvolvimento e não deve ser usada em produção. Para a versão final, será necessário migrar para AudioDriverKit e implementar assinatura de código adequada.