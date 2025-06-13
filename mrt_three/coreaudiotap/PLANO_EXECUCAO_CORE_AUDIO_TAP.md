# Plano de Execução: POC Core Audio TAP para macOS 14+

## Objetivo
Criar uma aplicação mínima de teste que demonstre a captura de áudio do sistema usando Core Audio TAP, seguindo a arquitetura de helper tool privilegiada com comunicação XPC.

## Análise Técnica

### Arquitetura Necessária
1. **Aplicação Principal**: SwiftUI app que funciona como cliente XPC
2. **Helper Tool Privilegiada**: Command line tool que executa as operações Core Audio TAP
3. **Comunicação XPC**: Interface segura entre app principal e helper tool
4. **SMJobBless**: Sistema para instalar a helper tool com privilégios elevados

### Componentes Críticos
- **Core Audio TAP**: `AudioHardwareCreateProcessTap` para capturar áudio de processos
- **Aggregate Device**: Dispositivo virtual que torna o áudio capturado disponível como entrada
- **AudioDeviceIOProc**: Callback de tempo real para processar dados de áudio
- **Code Signing**: Assinatura com Developer ID para ambos os alvos

## Fases de Implementação

### Fase 1: Estrutura Base do Projeto ✅
- [x] Analisar documento técnico
- [ ] Criar projeto Xcode com dois alvos (App + Helper Tool)
- [ ] Configurar estrutura de arquivos e dependências

### Fase 2: Configuração de Segurança e Privilégios
- [ ] Configurar Info.plist com SMPrivilegedExecutables
- [ ] Criar launchd.plist para helper tool
- [ ] Configurar entitlements para system-audio-capture
- [ ] Setup code signing para Developer ID

### Fase 3: Implementação SMJobBless
- [ ] Criar HelperManager para instalação da helper tool
- [ ] Implementar autorização e chamada SMJobBless
- [ ] Tratar erros comuns de instalação

### Fase 4: Protocolo e Comunicação XPC
- [ ] Definir AudioHelperProtocol em Objective-C
- [ ] Implementar cliente XPC na aplicação principal
- [ ] Configurar NSXPCConnection com validação de segurança

### Fase 5: Helper Tool Privilegiada
- [ ] Implementar main.m com NSXPCListener
- [ ] Criar AudioCaptureService conformando ao protocolo
- [ ] Implementar Core Audio TAP com validação de cliente
- [ ] Configurar AudioDeviceIOProc para captura em tempo real

### Fase 6: Interface de Usuário
- [ ] Criar SwiftUI básica com botões Start/Stop
- [ ] Exibir status da conexão e captura
- [ ] Mostrar informações de debug e logs

### Fase 7: Teste e Depuração
- [ ] Testar instalação da helper tool
- [ ] Verificar comunicação XPC
- [ ] Validar captura de áudio do sistema
- [ ] Depurar problemas com Console.app

## Estrutura de Arquivos Proposta
```
CoreAudioTapPOC/
├── CoreAudioTapPOC/           # Aplicação principal
│   ├── ContentView.swift
│   ├── HelperManager.swift
│   ├── XPCClient.swift
│   ├── Info.plist
│   └── CoreAudioTapPOC.entitlements
├── AudioCaptureHelper/        # Helper tool
│   ├── main.m
│   ├── AudioCaptureService.h
│   ├── AudioCaptureService.m
│   ├── Info.plist
│   ├── Helper-Launchd.plist
│   └── AudioCaptureHelper.entitlements
└── Shared/
    └── AudioHelperProtocol.h
```

## Pontos Críticos de Atenção

### Segurança
- Validação rigorosa de clientes XPC usando audit_token
- Princípio do menor privilégio na helper tool
- Assinatura de código com certificado Developer ID válido

### Performance
- AudioDeviceIOProc executa em thread de tempo real
- Usar ring buffer para transferir dados de áudio
- Processamento em thread separada de menor prioridade

### Compatibilidade
- macOS 14+ para Core Audio TAP
- Entitlement com.apple.security.system-audio-capture
- Remover App Sandbox para distribuição fora da Mac App Store

## Métricas de Sucesso
1. ✅ Helper tool instalada via SMJobBless sem erros
2. ✅ Comunicação XPC estabelecida entre app e helper
3. ✅ Core Audio TAP criado com sucesso para processo alvo
4. ✅ Aggregate Device configurado e funcional
5. ✅ Dados de áudio capturados em tempo real
6. ✅ Interface de usuário responsiva com feedback de status

## Próximos Passos após POC
- Integração com aplicação principal de gravação de reuniões
- Otimização de performance e uso de memória
- Implementação de filtros e processamento de áudio
- Testes em diferentes configurações de sistema
- Preparação para distribuição e codesigning de produção

## Comandos de Desenvolvimento
```bash
# Build do projeto
xcodebuild -project CoreAudioTapPOC.xcodeproj -scheme CoreAudioTapPOC clean build

# Verificar assinatura
codesign -dvvv CoreAudioTapPOC.app
codesign -dvvv CoreAudioTapPOC.app/Contents/Library/LaunchServices/AudioCaptureHelper

# Debug com Console.app
# Filtrar por "AudioCaptureHelper" para logs da helper tool

# Verificar helper tool instalada
sudo launchctl list | grep com.empresa.CoreAudioTapPOC.Helper
```

---
*Este plano será atualizado conforme o progresso da implementação.*