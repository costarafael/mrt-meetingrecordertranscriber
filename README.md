# MRT - Meeting Recorder & Transcriber (macOS)

Aplicativo para gravação e transcrição de reuniões para macOS.

## 📋 Sobre o Projeto

MRT (Meeting Recorder & Transcriber) é uma aplicação para macOS desenvolvida para capturar, gravar e transcrever reuniões de maneira eficiente. O projeto utiliza tecnologias de áudio avançadas do macOS para garantir alta qualidade de gravação e recursos de IA para transcrição precisa.

## 🚀 Configuração do Ambiente

Para configurar o ambiente de desenvolvimento:

```bash
# Clone o repositório
git clone https://github.com/costarafael/mrt-meetingrecordertranscriber.git
cd mrt-meetingrecordertranscriber

# Configure o ambiente
chmod +x Scripts/setup_environment.sh
./Scripts/setup_environment.sh
```

## 🏗️ Arquitetura

O projeto segue uma arquitetura modular baseada em:

- **SOLID Principles**: Princípios de design orientado a objetos
- **Protocol-Oriented**: Interfaces compartilhadas através de protocolos
- **Clean Architecture**: Separação clara de responsabilidades
- **Dependency Injection**: Gerenciamento eficiente de dependências

## 📁 Estrutura de Diretórios

```
mrt_macos_app/
  ├── Sources/              # Código-fonte Swift
  │   ├── App/              # Configuração da aplicação
  │   ├── Core/             # Modelos, enums e protocolos core
  │   │   └── Audio/        # Componentes de áudio
  │   ├── Models/           # Modelos de dados
  │   ├── Services/         # Serviços da aplicação
  │   │   ├── Audio/        # Serviços de áudio
  │   │   ├── Logging/      # Serviços de logging
  │   │   └── Recording/    # Serviços de gravação
  │   ├── ViewModels/       # View models
  │   └── Views/            # Componentes de UI
  └── Scripts/              # Scripts de configuração e utilitários
```

## 📚 Documentação

- [Padrões de Logging](LOGGING_STANDARD.md)
- [Resumo da Implementação](IMPLEMENTATION_SUMMARY.md)
- [Arquitetura](ARQUITETURA.md)
- [Documentação de Serviços](SERVICES_DOCUMENTATION.md)

## ⚙️ Plano de Execução

O desenvolvimento segue um plano estruturado em fases:

1. **Fase 0**: Preparação ✅
2. **Fase 1**: Padronização ✅
3. **Fase 2**: Refatoração
4. **Fase 3**: Melhorias
5. **Fase 4**: Finalização

## 🤝 Contribuição

Para contribuir com o projeto:

1. Siga os padrões de código estabelecidos no [Style Guide](STYLE_GUIDE.md)
2. Utilize o LoggingService para todos os logs
3. Implemente testes unitários para novas funcionalidades
4. Envie Pull Requests para a branch correta de acordo com a fase atual

## 📄 Licença

Este projeto é licenciado sob a licença MIT - veja o arquivo LICENSE para detalhes. 