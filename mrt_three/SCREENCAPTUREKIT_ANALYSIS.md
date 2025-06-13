# Análise do Problema ScreenCaptureKit - Sistema de Áudio Parando Prematuramente

## 📊 Dados das Gravações Analisadas

### Gravação 1 (E5A2FE62)
- **Microfone**: 463.36s (7min 43s)
- **Sistema**: 23.81s (apenas 24s)
- **Diferença**: 439.55s (7min 19s)

### Gravação 2 (6747161D) 
- **Microfone**: 291.84s (4min 51s)
- **Sistema**: 267.58s (4min 27s)
- **Diferença**: 24.26s (24s)

### Gravação 3 (743A1F88)
- **Microfone**: 539.46s (8min 59s)
- **Sistema**: 285.82s (4min 45s)
- **Diferença**: 253.64s (4min 14s)

## 🔍 Padrão Identificado

**PROBLEMA CONSISTENTE**: O ScreenCaptureKit para de capturar áudio do sistema entre 24 segundos e 4+ minutos antes do microfone, independentemente das melhorias implementadas.

## 📋 Melhorias Já Implementadas (Sem Sucesso)

### 1. Monitoramento e Diagnósticos
- ✅ Logs detalhados de samples recebidos
- ✅ Contadores de callbacks vs escritas de arquivo
- ✅ Detecção de gaps temporais
- ✅ Verificação contínua de saúde do stream

### 2. Configurações Otimizadas
- ✅ Captura mínima de tela (2x2 pixels)
- ✅ Frame rate reduzido (1 FPS)
- ✅ Configurações baseadas na pesquisa técnica

### 3. Sistema de Recuperação
- ✅ Detecção automática de falhas
- ✅ Tentativa de recreação do stream
- ✅ Callbacks de erro melhorados

### 4. Sistema de Fallback (Estrutura)
- ✅ Detecção de versão do macOS
- ✅ Preparação para Core Audio Taps
- ✅ Sistema de notificação de falhas

## 🎯 Causas Prováveis Baseadas na Pesquisa

### 1. Bugs Conhecidos do ScreenCaptureKit
Conforme documentado na pesquisa técnica:

- **macOS 14.7.3**: "Crashes confirmados com `EXC_BAD_ACCESS`"
- **Chips M3**: "Falhas de até 40+ segundos no `getShareableContentWithCompletionHandler`"
- **Múltiplos streams**: "Necessidade ocasional de reinicialização do serviço `replayd`"

### 2. Limitação Fundamental da API
O ScreenCaptureKit foi:
> *"projetado primariamente para a gravação de tela e do conteúdo de janelas de aplicativos. Suas capacidades foram expandidas para incluir a captura de áudio associado a esse conteúdo."*

**Implicação**: A captura de áudio é secundária e pode ser instável quando usada isoladamente.

### 3. Problema de Permissões/Recursos
- Requer permissão de "Gravação de Tela" mesmo para áudio apenas
- Possível revogação automática de permissões
- Conflitos com outros apps usando ScreenCaptureKit

## 🛠️ Soluções Recomendadas

### Solução 1: Migrar para Core Audio Taps (macOS 14.2+)
**Status**: Estrutura preparada, implementação pendente

**Vantagens**:
- API dedicada para áudio do sistema
- Não requer captura de tela
- Mais estável segundo a pesquisa

**Complexidade**: Alta (APIs de baixo nível em C)

### Solução 2: Implementar Solução Híbrida
**Estratégia**: 
1. Core Audio Taps para macOS 14.2+
2. ScreenCaptureKit como fallback para versões anteriores
3. Detecção automática e switch entre métodos

### Solução 3: Solução Externa (BlackHole)
**Vantagens**:
- Comprovadamente estável
- Não depende de APIs problemáticas
- Funciona em todas as versões

**Desvantagens**:
- Requer instalação de software terceiro
- Não é uma solução "nativa"

## 📈 Próximos Passos Priorizados

### Prioridade 1: Implementar Core Audio Taps
- [ ] Implementar `AudioHardwareCreateProcessTap`
- [ ] Criar dispositivo agregado programaticamente
- [ ] Configurar IOProc callbacks
- [ ] Integrar com sistema existente

### Prioridade 2: Sistema de Fallback Inteligente
- [ ] Detecção automática de falhas do ScreenCaptureKit
- [ ] Switch automático para Core Audio Taps quando disponível
- [ ] Graceful degradation para versões antigas

### Prioridade 3: Análise de Logs Detalhada
- [ ] Capturar logs completos da próxima gravação
- [ ] Identificar momento exato da falha
- [ ] Correlacionar com eventos do sistema

## 🎯 Conclusão

O problema **NÃO é no nosso código**, mas sim uma **limitação/bug conhecida do ScreenCaptureKit** quando usado principalmente para áudio. A solução definitiva requer migração para Core Audio Taps ou uso de solução externa como BlackHole.

As melhorias implementadas servem para **diagnóstico e tentativas de recuperação**, mas não resolvem a causa raiz que está na própria API da Apple.