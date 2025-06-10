# Mapeamento de Dependências

## Serviços Principais
- **LoggingService** → Todos os serviços
- **AudioRecordingCoordinator** → MicrophoneCaptureService, SystemAudioCaptureService
- **AudioFileService** → AudioFileManager, AudioSynchronizer
- **DiagnosticsService** → LoggingService

## Estrutura de Dependências
```
LoggingService ← DiagnosticsService
             ↑
             | 
AudioRecordingCoordinator ← AudioFileService
             ↑                      ↑
             |                      |
MicrophoneCaptureService   AudioFileManager
SystemAudioCaptureService  AudioSynchronizer
```

## Critérios de Validação
- **Padronização**: 100% dos serviços usando LoggingService
- **Refatoração**: Todos os testes passando
- **Melhorias**: Performance validada
- **Finalização**: Documentação completa

## Ambiente
- Branch: `fase0-preparacao` e `fase1-padronizacao`
- Ambiente de testes: Configurado para macOS
- Ferramentas: Xcode, SwiftLint, XCTest 