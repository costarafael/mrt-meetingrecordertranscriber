# Padrões de Logging

Este documento define os padrões de logging para o projeto MRT macOS.

## Categorias de Log

Todas as mensagens de log devem utilizar uma das seguintes categorias:

- **General**: Logs gerais do sistema
- **Audio**: Relacionados a captura, processamento e reprodução de áudio
- **Recording**: Específicos para o processo de gravação
- **File**: Operações de arquivo
- **UI**: Eventos de interface
- **Network**: Comunicações de rede
- **Performance**: Métricas de desempenho
- **Diagnostics**: Informações de diagnóstico

## Níveis de Log

Os seguintes níveis devem ser utilizados conforme a severidade:

- **debug**: Informações detalhadas, úteis apenas durante desenvolvimento
- **info**: Informações sobre o fluxo normal da aplicação
- **warning**: Situações potencialmente problemáticas que não impedem a operação
- **error**: Erros que impedem uma função específica
- **critical**: Falhas críticas que impedem a operação da aplicação

## Padronização de Mensagens

### Início/Fim de Operações
```swift
logger.startOperation("Nome da operação", category: .categoria)
// ... código da operação ...
operationTimer.finish(success: true)
```

### Eventos de Áudio
```swift
logger.audioEvent("Descrição do evento", details: [
    "chave1": valor1,
    "chave2": valor2
])
```

### Operações de Arquivo
```swift
logger.fileOperation("Descrição da operação", path: "/caminho/do/arquivo")
```

### Erros
```swift
logger.error("Descrição do erro", error: erroCapturado, category: .categoria)
```

### Fallback
```swift
// No FallbackStrategy
func logFallbackEvent(error: AudioError, success: Bool) {
    if success {
        logger.info("✅ Fallback aplicado com sucesso para erro: \(error.localizedDescription)", category: .audio)
    } else {
        logger.error("❌ Fallback falhou para erro: \(error.localizedDescription)", category: .audio)
    }
}
```

## Boas Práticas

1. Sempre utilize o LoggingService em vez de print()
2. Inclua detalhes relevantes nas mensagens (IDs, valores, caminhos)
3. Não inclua dados sensíveis nos logs
4. Use emojis apenas para melhorar a visualização, não substituindo o texto
5. Mantenha as mensagens concisas e informativas

## Exemplos

### Boa Mensagem
```swift
logger.info("Arquivo de áudio processado com sucesso", category: .file)
logger.audioEvent("Captura iniciada", details: ["sampleRate": 44100, "channels": 2])
logger.error("Falha ao salvar arquivo", error: error, category: .file)
```

### Mensagem Inadequada
```swift
logger.debug("Ops!")  // Falta contexto
logger.info("Erro no sistema")  // Falta detalhes e deveria usar nível de erro
logger.error("Não foi possível continuar")  // Falta detalhes específicos
``` 