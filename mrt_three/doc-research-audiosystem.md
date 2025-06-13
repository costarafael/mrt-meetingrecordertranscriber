# RESUMO

**CONSIDERACAO IMPORTANTE: NOSSA META É SERVIR DO MAC OS 13+ EM DIANTE**

# Resumo: Gravação Nativa de Áudio Mixado (Sistema + Microfone) no macOS

Este material apresenta duas pesquisas técnicas abrangentes sobre a implementação nativa de captura simultânea de áudio do sistema e microfone no macOS, com foco na mixagem e normalização para 16kHz usando Swift 5.9.

## **Evolução das APIs de Captura de Áudio**

### **Marcos Históricos**
- **Pré-macOS 12.3**: Dependência de soluções terceirizadas (BlackHole, Soundflower) devido à ausência de APIs nativas robustas
- **macOS 12.3 (2022)**: Introdução revolucionária do **ScreenCaptureKit**, oferecendo primeira solução nativa para áudio do sistema
- **macOS 13+**: Melhorias significativas de performance e estabilidade
- **macOS 14.2+**: Introdução dos **Core Audio Taps** para controle granular de baixo nível
- **macOS 15+**: Adição de captura integrada de microfone via ScreenCaptureKit

## **Frameworks Principais e Suas Aplicações**

### **1. ScreenCaptureKit (Recomendado Principal)**
- **Disponibilidade**: macOS 12.3+
- **Funcionalidades**: Captura nativa de áudio do sistema, opcionalmente microfone
- **Vantagens**: API moderna, integração natural com captura de tela, suporte a até 48kHz estéreo
- **Limitações**: Requer permissão de "Gravação de Tela", possíveis instabilidades em versões anteriores

### **2. Core Audio Taps (Para Controle Avançado)**
- **Disponibilidade**: macOS 14.2+
- **Funcionalidades**: Controle de baixo nível, captura específica por processo
- **Vantagens**: Máximo controle granular, API oficial dedicada
- **Limitações**: Complexidade de implementação muito alta, restrito a versões recentes

### **3. AVFoundation (Essencial para Microfone)**
- **Disponibilidade**: macOS 10.10+ (AVAudioEngine)
- **Funcionalidades**: Captura robusta de microfone, mixagem, processamento
- **Vantagens**: API madura, excelente para mixagem e gravação
- **Limitações**: Sem suporte direto para áudio do sistema

## **Pipelines de Implementação Recomendados**

### **Pipeline A: ScreenCaptureKit + AVAudioEngine (Recomendado)**
```
Áudio Sistema (SCK) → CMSampleBuffer → Conversão → AVAudioPCMBuffer
                                                         ↓
                                                  AVAudioMixerNode
                                                         ↑
Microfone (AVEngine) → AVAudioInputNode → Tap → AVAudioPCMBuffer
                                                         ↓
                                              Saída Mixada 16kHz
```

**Vantagens**: Combina robustez do SCK com maturidade do AVAudioEngine
**Compatibilidade**: macOS 12.3+ (com limitações em versões anteriores à 13)

### **Pipeline B: Core Audio Taps + AVAudioEngine (Versões Recentes)**
- **Aplicação**: macOS 14.2+ apenas
- **Benefícios**: Controle máximo, API dedicada para áudio do sistema
- **Complexidade**: Muito alta, requer expertise em Core Audio

## **Desafios Técnicos Críticos**

### **1. Sincronização Temporal**
- **Problema**: Diferentes domínios de relógio entre ScreenCaptureKit e AVAudioEngine
- **Solução**: Alinhamento baseado em Host Time (`mach_absolute_time()`)
- **Implementação**: Compensação de offset calculada a partir de timestamps de ambas as fontes

### **2. Conversão de Formato e Sample Rate**
```swift
// Normalização para 16kHz
let targetFormat = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
let converter = AVAudioConverter(from: sourceFormat, to: targetFormat)
converter?.sampleRateConverterQuality = .high
```

### **3. Gerenciamento de Permissões**
**Info.plist obrigatório**:
- `NSMicrophoneUsageDescription` - Acesso ao microfone
- `NSAudioCaptureUsageDescription` - Áudio do sistema (Core Audio Taps)
- `NSScreenCaptureDescription` - ScreenCaptureKit

**Entitlements para App Sandbox**:
- `com.apple.security.device.audio-input` - Microfone
- `com.apple.security.system.audio-input` - Áudio do sistema
- `com.apple.security.screencapture` - ScreenCaptureKit

## **Implementação Prática para 16kHz**

### **Configuração de Gravação Otimizada**
```swift
// Configurações para AAC 16kHz
let audioSettings: [String: Any] = [
    AVFormatIDKey: kAudioFormatMPEG4AAC,
    AVNumberOfChannelsKey: 1,
    AVSampleRateKey: 16000.0,
    AVEncoderBitRateKey: 64000  // Otimizado para 16kHz
]

// Configurações para PCM 16kHz
let pcmSettings: [String: Any] = [
    AVFormatIDKey: Int(kAudioFormatLinearPCM),
    AVSampleRateKey: 16000.0,
    AVNumberOfChannelsKey: 1,
    AVLinearPCMBitDepthKey: 16,
    AVLinearPCMIsFloatKey: false
]
```

## **Limitações e Considerações Especiais**

### **Hardware**
- **AirPods Pro**: Limitados a 16kHz máximo na gravação
- **Macs Apple Silicon**: Possíveis incompatibilidades com interfaces USB
- **Dispositivos Bluetooth**: Latência adicional e degradação de qualidade

### **Bugs Conhecidos**
- **macOS 14.7.3**: Crashes confirmados com `EXC_BAD_ACCESS`
- **Chips M3**: Falhas de até 40+ segundos no `getShareableContentWithCompletionHandler`
- **Múltiplos streams**: Necessidade ocasional de reinicialização do serviço `replayd`

## **Recomendações Finais**

### **Estratégia de Compatibilidade**
1. **macOS 14.2+**: Core Audio Taps + AVAudioEngine (máximo controle)
2. **macOS 13+**: ScreenCaptureKit + AVAudioEngine (equilibrio ideal)
3. **macOS 12.3-12.x**: ScreenCaptureKit com tratamento extra de erros

### **Melhores Práticas Essenciais**
- Implementar tratamento robusto de erro para instabilidades conhecidas
- Usar buffer pools para evitar alocações frequentes durante gravação
- Pré-alocar conversores de formato durante inicialização
- Monitorar performance (CPU, memória, térmica)
- Fornecer degradação graciosa para hardware não suportado
- Teste abrangente em diferentes versões macOS e configurações hardware

A implementação bem-sucedida requer compreensão profunda das capacidades e limitações atuais, com planejamento cuidadoso para contornar restrições conhecidas e otimizar para diferentes cenários de hardware e software.


# PESQUISAS

Gravação e Mixagem Nativa de Áudio do Sistema e Microfone no macOS com Swift 5.91. IntroduçãoPropósito do Relatório:Este relatório técnico detalha o processo de desenvolvimento de uma solução nativa em Swift 5.9 para sistemas macOS, focada na gravação simultânea de áudio do sistema e da entrada de microfone. O objetivo final é a produção de um único arquivo de áudio contendo a mixagem dessas duas fontes. A abordagem prioriza o uso de APIs e frameworks fornecidos pela Apple, garantindo uma integração otimizada e conformidade com as diretrizes do macOS.Importância e Casos de Uso:A capacidade de capturar e combinar áudio do sistema com a entrada do microfone é fundamental para uma variedade de aplicações modernas. Softwares de screencasting, por exemplo, dependem dessa funcionalidade para criar tutoriais e demonstrações ricas em conteúdo. Ferramentas de produção de conteúdo, como as utilizadas para podcasts e streaming de jogos, também se beneficiam enormemente da mixagem de áudio em tempo real ou pós-captura. Adicionalmente, aplicações voltadas para acessibilidade podem utilizar essa técnica para fornecer feedback auditivo aprimorado, e ferramentas de análise de áudio podem processar interações complexas entre o usuário e o sistema.Abordagem Nativa:O foco deste relatório recai exclusivamente sobre as soluções nativas oferecidas pelo ecossistema da Apple. A utilização direta dos frameworks da Apple, como Core Audio, AVFoundation e ScreenCaptureKit, não apenas assegura o melhor desempenho e estabilidade, mas também alinha o desenvolvimento com as práticas recomendadas pela Apple, facilitando a manutenção e a compatibilidade futura com as evoluções do macOS.Visão Geral do Conteúdo:Este documento explorará os diversos frameworks de áudio disponíveis no macOS, detalhando suas capacidades e limitações no contexto da captura de áudio do sistema e do microfone. Serão analisadas estratégias específicas para cada tipo de captura, com ênfase nas versões do macOS que suportam tais funcionalidades. Posteriormente, será proposto um pipeline para a mixagem das fontes de áudio capturadas. Aspectos cruciais como o gerenciamento de permissões de usuário e as configurações do App Sandbox serão minuciosamente abordados. Finalmente, serão apresentadas considerações sobre a compatibilidade entre diferentes versões do macOS, juntamente com recomendações e melhores práticas para a implementação de uma solução robusta e eficiente.2. Visão Geral dos Frameworks de Captura de Áudio no macOSContexto:A manipulação de áudio no macOS é suportada por um conjunto robusto e multifacetado de frameworks. A escolha da ferramenta mais adequada para uma tarefa específica, como a gravação de áudio do sistema e do microfone, depende intrinsecamente dos requisitos do projeto, incluindo a versão mínima do macOS a ser suportada, o nível de controle desejado sobre o fluxo de áudio e a complexidade de implementação que o desenvolvedor está disposto a enfrentar. Cada framework oferece um conjunto distinto de capacidades, desde o controle de baixo nível do hardware até abstrações de alto nível que simplificam tarefas comuns.Análise Detalhada dos Frameworks:

Core Audio:

Descrição: Representa a camada fundamental para processamento de áudio no macOS e iOS, oferecendo o mais alto grau de controle sobre o hardware de áudio e o fluxo de dados.1 É a escolha preferencial para aplicações que demandam performance em tempo real, baixa latência e manipulação precisa de amostras de áudio.
Relevância para a Tarefa: Para a captura de áudio do sistema, o Core Audio tornou-se particularmente relevante com a introdução dos "Audio Taps" em versões mais recentes do macOS (especificamente macOS 14.2 e posteriores), permitindo a interceptação direta do áudio de saída do sistema.3
Principais Componentes: A interação com Core Audio envolve conceitos como AudioObjectID (identificadores únicos para objetos de áudio, como dispositivos), AudioBufferList (estruturas que contêm os dados de áudio), AudioStreamBasicDescription (ASBD, que define o formato do fluxo de áudio) e IOProcs (funções de callback para processamento de áudio em tempo real).2



AVFoundation:

Descrição: É um framework de alto nível que provê uma interface abrangente para trabalhar com mídia baseada em tempo, incluindo áudio e vídeo.1 Ele simplifica muitas das tarefas complexas gerenciadas pelo Core Audio, tornando-o mais acessível para uma ampla gama de aplicações.
Relevância para a Tarefa: AVFoundation é essencial para diversas partes do projeto:

Captura de Microfone: AVAudioEngine e seu AVAudioInputNode são as ferramentas padrão para capturar áudio da entrada de microfone.5
Mixagem de Áudio: AVAudioEngine, com seu mainMixerNode ou AVAudioMixerNode customizados, é ideal para combinar múltiplas fontes de áudio.8
Escrita de Arquivos de Áudio: Classes como AVAudioRecorder (para gravação simples), AVAudioFile (para leitura e escrita de arquivos de áudio com AVAudioPCMBuffer) e AVAssetWriter (para cenários mais complexos, incluindo áudio e vídeo) são fornecidas por este framework.11


Disponibilidade: AVAudioEngine, um componente central para as funcionalidades desejadas, está disponível no macOS desde a versão 10.10.5



ScreenCaptureKit:

Descrição: Introduzido mais recentemente, o ScreenCaptureKit foi projetado primariamente para a gravação de tela e do conteúdo de janelas de aplicativos.13 Suas capacidades foram expandidas para incluir a captura de áudio associado a esse conteúdo.15
Relevância para a Tarefa: Este framework pode ser utilizado para capturar tanto o áudio do sistema (através de SCStreamOutputType.audio) quanto o áudio do microfone (configurando SCStreamConfiguration.captureMicrophone = true e utilizando SCStreamOutputType.microphone).5
Considerações de Versão: A capacidade e a forma de capturar áudio com ScreenCaptureKit evoluíram. A captura de áudio do sistema e, mais notavelmente, do microfone, juntamente com a robustez dessas funcionalidades, varia conforme a versão do macOS. Por exemplo, o Ecamm Live passou a usar ScreenCaptureKit para captura de áudio do sistema a partir do macOS 13, e removeu seu plugin de áudio proprietário com o macOS 14.4, sugerindo melhorias na capacidade nativa do SCK.17 Funcionalidades específicas como salvar a saída do microfone diretamente em um arquivo são mencionadas no contexto do macOS 15+.5 O suporte geral ao ScreenCaptureKit começou com o macOS 12.3.18


A evolução das APIs de captura de áudio do sistema no macOS ilustra uma transição interessante. Inicialmente, a captura nativa de áudio do sistema era uma tarefa complexa, frequentemente levando os desenvolvedores a recorrerem a soluções de terceiros, como o popular BlackHole, para criar dispositivos de áudio virtuais que pudessem rotear e capturar o som do sistema.19 Reconhecendo a demanda por essa funcionalidade, a Apple começou a introduzir gradualmente mecanismos nativos. O ScreenCaptureKit, embora focado em vídeo, foi um dos primeiros a oferecer uma forma de capturar áudio do sistema de maneira integrada.13 Mais recentemente, a introdução dos Core Audio Taps no macOS 14.2+ representou um passo significativo, fornecendo uma API de baixo nível, poderosa e dedicada para essa finalidade.3 Essa trajetória de desenvolvimento implica que a abordagem "ideal" para a captura de áudio do sistema é fortemente dependente da versão do macOS que o aplicativo pretende suportar. Desenvolvedores que visam uma ampla compatibilidade podem precisar implementar estratégias condicionais ou aceitar que certas funcionalidades nativas não estarão disponíveis em versões mais antigas do sistema operacional.Enquanto Core Audio e ScreenCaptureKit oferecem mecanismos para capturar os fluxos de áudio bruto, o AVAudioEngine do AVFoundation emerge consistentemente como a solução central para o processamento e a mixagem subsequente dessas fontes. Seja o áudio proveniente de um Core Audio Tap, de um stream do ScreenCaptureKit ou diretamente da entrada do microfone via AVAudioInputNode, o AVAudioEngine fornece as ferramentas necessárias, como o AVAudioMixerNode ou o mainMixerNode, para combinar esses fluxos de forma flexível e eficiente.7 Isso sugere que qualquer pipeline de gravação que envolva a mixagem de áudio do sistema e do microfone provavelmente utilizará o AVAudioEngine em algum momento, independentemente da tecnologia específica empregada para a captura inicial de cada fonte.Tabela Comparativa de Frameworks para Captura de Áudio:
FuncionalidadeCore AudioAVFoundationScreenCaptureKitCaptura de Áudio do Sistema (Nativo)Sim (via Audio Taps, macOS 14.2+) 3Não diretamente para áudio do sistema.Sim (SCStreamOutputType.audio) 13Captura de Áudio do MicrofoneSim (baixo nível, complexo)Sim (AVAudioEngine, AVAudioInputNode) 6Sim (captureMicrophone=true, SCStreamOutputType.microphone) 5Versão Mínima do macOS (Func. Chave)Audio Taps: macOS 14.2+.3 Geral: mais antigo.AVAudioEngine: macOS 10.10+.5 AVAudioSourceNode (com AudioTimeStamp): macOS 10.15+.21Geral: macOS 12.3+.18 Captura de áudio do sistema: macOS 13+ (com variações).17 Mic: macOS 15+ (algumas func.).5Nível de APIBaixoAlto/MédioAltoComplexidade de ImplementaçãoAltaModeradaModerada (para áudio pode ser mais complexo do que parece)Principais Casos de UsoProcessamento de áudio de baixa latência, controle de hardware, Audio Taps.Gravação/reprodução de áudio, processamento, mixagem, captura de microfone.Gravação de tela e conteúdo de apps, captura de áudio associado.PrósControle granular máximo, alta performance.Mais fácil de usar para tarefas comuns, boa integração com o sistema, robusto para microfone e mixagem.Integrado para captura de tela e áudio, API mais recente para captura de conteúdo.ContrasCurva de aprendizado íngreme, verboso, gerenciamento manual de recursos.Menos controle de baixo nível que Core Audio. Sincronização pode ser desafiadora.22Primariamente para tela, áudio pode ser secundário. Confiabilidade/bugs em versões anteriores.13 Requer permissão de tela.
3. Captura Nativa de Áudio do SistemaA captura do áudio que está sendo reproduzido pelo sistema operacional, excluindo a entrada do microfone, é uma funcionalidade poderosa com implicações significativas de privacidade. Historicamente, a Apple tornou essa tarefa nativamente desafiadora, o que levou ao surgimento de soluções de terceiros como o BlackHole.19 No entanto, com as evoluções recentes do macOS, surgiram APIs nativas que abordam essa necessidade, embora com controles e requisitos de permissão rigorosos, refletindo a sensibilidade da funcionalidade.Opção 1: Core Audio Taps (Recomendado para macOS 14.2+)Esta é a API mais recente e de mais baixo nível fornecida pela Apple, especificamente projetada para a captura de áudio do sistema, oferecendo grande flexibilidade e controle.3

Funcionamento Detalhado:A implementação de Core Audio Taps envolve vários componentes chave:

CATapDescription: Este objeto é usado para configurar o "tap" de áudio. Ele permite especificar quais processos devem ser capturados (ou todos os processos do sistema), se o tap é privado para a aplicação que o criou, o comportamento de mudo (se o áudio original deve ser silenciado na saída principal) e opções de mixdown (como converter áudio estéreo para mono).2
AudioHardwareCreateProcessTap: Esta função do Core Audio é chamada com a CATapDescription configurada para criar efetivamente o tap. Ela retorna um AudioObjectID que identifica o novo tap.2
Dispositivos Agregados (Aggregate Devices): Para que um Core Audio Tap seja utilizável como uma fonte de áudio padrão por outras APIs de nível superior, como o AVAudioEngine, ele precisa ser incorporado a um Dispositivo Agregado. Este dispositivo agregado virtualiza o tap como se fosse um dispositivo de entrada de áudio físico, como um microfone.3

A criação do dispositivo agregado é feita programaticamente usando AudioHardwareCreateAggregateDevice.3
Após a criação, o tap (identificado por seu AudioObjectID e UID) é adicionado à lista de taps do dispositivo agregado através da propriedade kAudioAggregateDevicePropertyTapList.3 A necessidade de criar e gerenciar programaticamente um Dispositivo Agregado adiciona uma camada de complexidade ao processo de configuração.


IOProcs (Input/Output Procedures): São funções de callback de baixo nível que o sistema chama quando há novos dados de áudio disponíveis do tap. Essas IOProcs recebem os buffers de áudio em formato AudioBufferList.2 O processamento dentro de uma IOProc deve ser extremamente eficiente para evitar latência ou interrupções no áudio.



Permissões e Entitlements:

No arquivo Info.plist da aplicação, a chave NSAudioCaptureUsageDescription é obrigatória. Seu valor é uma string que será exibida ao usuário na primeira vez que o aplicativo tentar capturar o áudio do sistema, explicando o motivo da solicitação.2
Para aplicativos que utilizam App Sandbox, um entitlement específico é necessário. Fontes como 2 e 2 indicam o entitlement com.apple.security.system.audio-input (ou a variante com.apple.safety.system.audio-input). A documentação da Apple para Core Audio Taps 3 foca na chave do Info.plist e no prompt do sistema, mas o entitlement é o portão subjacente para acesso a recursos protegidos em um ambiente sandboxed.



Implementação em Swift (Diretrizes e Desafios):A interação direta com as APIs de Core Audio em Swift, embora poderosa, apresenta desafios. Requer um bom entendimento de ponteiros (como UnsafeMutablePointer), tratamento de códigos de erro OSStatus, e gerenciamento manual de memória em certos contextos. A conversão dos AudioBufferLists recebidos na IOProc para formatos mais palatáveis por frameworks de nível superior, como AVAudioPCMBuffer para AVAudioEngine, também é uma etapa crucial. Exemplos de código fornecidos pela Apple 3 e projetos de código aberto como AudioCap 2 e o gist de "sudara" 26 são recursos valiosos.


Prós: Oferece controle granular sobre a captura de áudio do sistema, é uma API oficial e direta para essa finalidade em versões recentes do macOS.


Contras: A complexidade de implementação é consideravelmente alta. Está restrito ao macOS 14.2 e versões posteriores. Em alguns cenários, especialmente para aplicativos distribuídos fora da Mac App Store ou que exigem privilégios elevados, pode ser necessário o uso de uma "helper tool" privilegiada para realizar as chamadas de Core Audio.27

Opção 2: ScreenCaptureKitEmbora seu propósito primário seja a gravação de tela e de janelas de aplicativos, o ScreenCaptureKit também pode ser configurado para capturar o áudio do sistema.13

Funcionamento Detalhado:

SCStreamConfiguration: Para habilitar a captura de áudio do sistema, a propriedade capturesAudio desta configuração deve ser definida como true. Opcionalmente, excludesCurrentProcessAudio pode ser usado para evitar que o áudio do próprio aplicativo seja capturado.16
SCStream: Um objeto SCStream é criado com a configuração apropriada. Para receber dados de áudio do sistema, um "output" do tipo .audio é adicionado ao stream usando o método addStreamOutput(_:type:sampleHandlerQueue:).2
SCStreamDelegate: O delegado do SCStream implementa o método stream(_:didOutputSampleBuffer:ofType:). Quando ofType é .audio, o sampleBuffer recebido (um CMSampleBuffer) contém os dados de áudio do sistema.13



Considerações de Versão do macOS:A capacidade de captura de áudio do sistema com ScreenCaptureKit está disponível em versões do macOS anteriores à 14.2. O framework em si foi introduzido com o macOS 12.3.18 Aplicações como o Ecamm Live utilizam ScreenCaptureKit para captura de áudio do sistema no macOS 13 e mais recentes.17 No entanto, a robustez e a confiabilidade da captura de áudio, especialmente quando usada isoladamente (sem vídeo), podem ter variado em versões mais antigas, com relatos de problemas como falhas ao iniciar o stream ou ausência de callbacks de áudio 13, particularmente em betas do macOS 15.


Permissões:A permissão principal solicitada ao usuário será a de "Gravação de Tela", pois o ScreenCaptureKit é fundamentalmente um framework de captura de tela. A chave NSScreenCaptureDescription no Info.plist é usada para justificar essa permissão. A documentação da Apple para ScreenCaptureKit 16 foca nas propriedades de configuração capturesAudio e excludesCurrentProcessAudio sem detalhar uma chave de Info.plist exclusiva para o áudio do sistema via SCK, mas a permissão de gravação de tela é o portal de entrada.


Implementação em Swift (Diretrizes e Desafios):A implementação envolve a configuração correta de SCStream, SCContentFilter (para definir o que está sendo capturado, mesmo que seja apenas áudio de um display) e SCStreamConfiguration. O processamento dos CMSampleBuffers de áudio recebidos no delegado é a etapa seguinte. Exemplos podem ser encontrados em discussões e códigos como os referenciados em.5 Um desafio particular pode ser a captura de áudio do sistema sem capturar vídeo; uma técnica mencionada é configurar a captura para uma área mínima da tela (e.g., 2x2 pixels) e ignorar os buffers de vídeo, focando apenas nos de áudio.23


Prós: API de nível mais alto em comparação com Core Audio Taps, pode capturar vídeo e áudio de forma sincronizada (se ambos forem desejados), e está disponível em versões do macOS anteriores à 14.2.


Contras: Foi primariamente desenhado para captura de tela, o que pode tornar a captura de áudio isolado menos direta ou sujeita a comportamentos inesperados em versões mais antigas.13 Requer permissão de gravação de tela mesmo que apenas o áudio seja o objetivo.

A escolha entre Core Audio Taps e ScreenCaptureKit para captura de áudio do sistema é, portanto, um compromisso entre o nível de controle, a complexidade de implementação e a amplitude de versões do macOS que precisam ser suportadas. Se o suporte a versões do macOS anteriores à 14.2 é um requisito crítico, ScreenCaptureKit se apresenta como a principal opção nativa, apesar de suas peculiaridades e potenciais instabilidades históricas para captura de áudio isolado. Para projetos que podem mirar o macOS 14.2 ou mais recente, os Core Audio Taps oferecem uma solução mais robusta, direta e tecnicamente elegante para a captura pura de áudio do sistema.4. Captura de Áudio do MicrofoneA captura de áudio da entrada de microfone é uma tarefa mais estabelecida e geralmente mais direta no macOS em comparação com a captura de áudio do sistema. O AVAudioEngine do framework AVFoundation é amplamente considerado o padrão para esta finalidade na maioria das aplicações Swift.Opção 1: AVFoundation (AVAudioEngine)Esta é a abordagem mais comum e recomendada para capturar áudio do microfone em aplicações macOS.

Funcionamento Detalhado:

AVAudioEngine: Instancia-se um motor de áudio, que gerenciará o grafo de processamento.5
AVAudioInputNode: O AVAudioEngine possui um inputNode que representa a entrada de áudio do hardware, tipicamente o microfone padrão do sistema ou o selecionado nas Preferências do Sistema.5
installTap(onBus:bufferSize:format:block:): Este método é chamado no inputNode para instalar um "tap" (ponto de escuta). O bloco fornecido a este método é invocado repetidamente com novos buffers de áudio (AVAudioPCMBuffer) assim que eles se tornam disponíveis da entrada do microfone.6



Seleção de Dispositivo:Por padrão, o inputNode do AVAudioEngine utiliza o dispositivo de entrada de áudio padrão configurado no sistema. Se for necessário selecionar um dispositivo de microfone específico (por exemplo, um microfone USB externo ou um dispositivo agregado que inclua uma entrada de microfone), a abordagem se torna mais complexa. Não há uma API Swift de alto nível no AVAudioEngine para definir diretamente o dispositivo de entrada por ID ou UID. Em vez disso, é preciso interagir com as APIs de Core Audio para obter o AudioDeviceID do dispositivo desejado e, em seguida, definir a propriedade kAudioUnitProperty_CurrentDevice no AudioUnit subjacente ao inputNode do AVAudioEngine.28 É importante notar que o AVAudioEngine pode criar seu próprio dispositivo agregado internamente, e interações com dispositivos agregados customizados podem levar a comportamentos inesperados, como contagens de canais incorretas, conforme discutido em 30 e.31


Permissões:A captura de áudio do microfone exige permissões explícitas do usuário:

Info.plist: A chave NSMicrophoneUsageDescription deve ser adicionada ao arquivo Info.plist do aplicativo. O valor desta chave é uma string que descreve ao usuário por que o aplicativo precisa de acesso ao microfone. Esta mensagem é exibida no alerta de permissão.5
App Sandbox: Se o aplicativo estiver configurado para rodar em um App Sandbox, o entitlement "Audio Input" (correspondente a com.apple.security.device.audio-input) deve ser habilitado nas capacidades do projeto.5
A ausência dessas configurações é uma causa comum de falha na captura de áudio, onde o aplicativo pode não receber buffers de áudio ou pode falhar silenciosamente sem erros óbvios.5



Implementação em Swift:Existem diversos exemplos e discussões sobre como implementar a captura de microfone com AVAudioEngine. 6 e 7 fornecem trechos de código básicos para instalar um tap e receber buffers. 10 mostra o uso do inputNode no contexto do ShazamKit, e 33 demonstra a gravação para um arquivo (usando LAME para compressão MP3, mas a parte da captura via tap no inputNode é relevante).


Prós: API de alto nível, bem documentada e amplamente utilizada. Integração direta e fácil com as funcionalidades de mixagem e processamento do AVAudioEngine.


Contras: A seleção de um dispositivo de entrada não padrão pode ser complexa, exigindo conhecimento de Core Audio. Problemas de sincronização e latência podem ocorrer, especialmente em cenários de processamento em tempo real ou loopback.6

Opção 2: ScreenCaptureKitEmbora não seja sua finalidade principal, o ScreenCaptureKit também oferece a capacidade de capturar áudio do microfone.

Funcionamento Detalhado:

SCStreamConfiguration: A propriedade captureMicrophone deve ser definida como true.2
SCStreamConfiguration (Opcional): A propriedade microphoneCaptureDeviceID pode ser usada para especificar o AudioDeviceID de um microfone particular. Se for nil, o microfone padrão do sistema será usado.2
SCStream: Um "output" do tipo .microphone é adicionado ao stream usando addStreamOutput(_:type:sampleHandlerQueue:).2
SCStreamDelegate: O método stream(_:didOutputSampleBuffer:ofType:) do delegado será invocado com CMSampleBuffers contendo o áudio do microfone quando ofType for .microphone.13



Considerações de Versão do macOS:A funcionalidade de captura de microfone via ScreenCaptureKit é uma adição relativamente mais recente ao framework. Referências em 5 e 5 indicam que, a partir do macOS 15, é possível configurar o SCRecordingOutput para salvar a saída do microfone diretamente em um arquivo. A propriedade captureMicrophone em si parece estar disponível em versões anteriores, embora a robustez e a facilidade de implementação possam variar.


Permissões:Assim como com AVAudioEngine, a chave NSMicrophoneUsageDescription no Info.plist e o entitlement "Audio Input" (para apps sandboxed) são cruciais.5 Adicionalmente, como a funcionalidade está dentro do ScreenCaptureKit, o sistema também solicitará a permissão de "Gravação de Tela".


Implementação em Swift:Exemplos de configuração podem ser encontrados em.5 Desenvolvedores relataram dificuldades para fazer essa abordagem funcionar corretamente, muitas vezes relacionadas a configurações de privacidade ou a problemas na própria API em certas versões.5


Prós: Pode ser uma opção conveniente se o ScreenCaptureKit já estiver sendo utilizado para captura de tela ou áudio do sistema, potencialmente oferecendo uma sincronização mais simples entre esses fluxos se o framework gerenciar os timestamps de forma consistente.


Contras: Requer a permissão de "Gravação de Tela" mesmo que apenas o áudio do microfone seja o objetivo, o que pode ser confuso para o usuário. É menos flexível para processamento de áudio complexo em comparação com AVAudioEngine. A confiabilidade pode ser uma preocupação, dado os relatos de problemas.

Para a maioria dos cenários que exigem captura de áudio do microfone, especialmente aqueles que envolvem processamento ou mixagem subsequente, o AVAudioEngine permanece a escolha mais direta, madura e robusta. A seleção de um dispositivo de microfone específico que não seja o padrão do sistema introduz uma camada de complexidade, frequentemente necessitando de interações com Core Audio, mesmo quando se utiliza AVAudioEngine. O ScreenCaptureKit pode ser uma alternativa em contextos onde já está em uso para outras capturas, mas os desenvolvedores devem estar cientes dos requisitos de permissão adicionais e da potencial instabilidade reportada.5. Pipeline Proposto: Gravando e Mixando Áudio do Sistema e MicrofoneA combinação das fontes de áudio do sistema e do microfone em um único fluxo coeso é o requisito central. Este processo introduz desafios significativos, principalmente relacionados à sincronização temporal dos diferentes fluxos de áudio.Desafio Central: SincronizaçãoCapturar áudio de duas fontes distintas, cada uma com seu próprio caminho de hardware e software, inevitavelmente resulta em latências diferentes. O áudio do sistema pode ter uma latência associada ao seu processamento interno e ao mecanismo de tap, enquanto o áudio do microfone terá latências relacionadas ao hardware do microfone, à interface de áudio e ao processamento do AVAudioInputNode. Essas diferenças podem levar a um desalinhamento perceptível entre as duas fontes no áudio mixado final, como um eco ou uma sensação de atraso.A reconciliação de timestamps é, portanto, crucial. O Core Audio opera com AudioTimeStamp, enquanto o AVFoundation utiliza AVAudioTime.34 Embora AVAudioTime possa ser inicializado a partir de um AudioTimeStamp, e ambos contenham informações de hostTime (baseado no clock do sistema mach_absolute_time()), a aplicação correta desses valores para alinhar buffers de diferentes origens é complexa.22 O ScreenCaptureKit também possui seu próprio synchronizationClock, mas sua interface com o AVAudioEngine para fins de sincronização não é claramente documentada, e problemas de sincronização entre áudio do sistema capturado por SCK e áudio de microfone são explicitamente mencionados em.35A seguir, são apresentadas estratégias de pipeline, considerando diferentes combinações das tecnologias de captura discutidas anteriormente.Estratégia A: Core Audio Taps (Sistema) + AVAudioEngine (Microfone e Mixagem)Esta estratégia é recomendada para macOS 14.2+ devido à dependência dos Core Audio Taps.

Captura de Áudio do Sistema:

Utilizar Core Audio Taps conforme descrito na Seção 3.1. A IOProc configurada receberá AudioBufferLists contendo o áudio do sistema.



Captura de Áudio do Microfone:

Utilizar o inputNode do AVAudioEngine conforme descrito na Seção 4.1. Um tap instalado neste nó fornecerá AVAudioPCMBuffers do microfone.



Alimentando Áudio do Sistema no AVAudioEngine:

Os AudioBufferLists provenientes do Core Audio Tap precisam ser convertidos para AVAudioPCMBuffers. 36 demonstra uma conversão de AudioBufferList para AVAudioPCMBuffer, embora o contexto original seja de um AudioUnitRender. A lógica pode ser adaptada.
Um AVAudioSourceNode é então usado para injetar programaticamente esses AVAudioPCMBuffers (contendo o áudio do sistema) no grafo do AVAudioEngine. O AVAudioSourceNode é projetado especificamente para cenários onde o áudio é fornecido de uma fonte customizada, como um callback.21 O renderBlock do AVAudioSourceNode é o local onde esses buffers são fornecidos ao motor.



Mixagem:

Dentro do AVAudioEngine, o AVAudioSourceNode (transportando o áudio do sistema) e o inputNode (transportando o áudio do microfone) são conectados ao mainMixerNode do motor ou a um AVAudioMixerNode customizado para controle de volume individual, pan, etc..8 O AVAudioEngine se encarrega da mixagem dos sinais.



Saída Mixada:

Para obter o áudio mixado para gravação, um tap é instalado na saída do mainMixerNode (ou do mixer customizado). Este tap fornecerá AVAudioPCMBuffers contendo o áudio combinado.7



Prós: Oferece controle granular sobre a captura de áudio do sistema através de uma API moderna (Core Audio Taps). Aproveita a robustez e a facilidade de uso do AVAudioEngine para a captura de microfone e para o processo de mixagem.
Contras: Restrito ao macOS 14.2 e posterior. A implementação do Core Audio Tap, a conversão de AudioBufferList para AVAudioPCMBuffer, e a alimentação correta do AVAudioSourceNode adicionam complexidade. A sincronização entre os dados recebidos na IOProc do Core Audio e o momento em que são consumidos pelo renderBlock do AVAudioSourceNode deve ser gerenciada com cuidado para minimizar latência e desalinhamento.
Estratégia B: ScreenCaptureKit (Áudio do Sistema e Microfone) + AVAudioEngine (Mixagem Opcional)Esta estratégia pode ser considerada para suportar versões do macOS anteriores à 14.2.

Captura de Áudio do Sistema e Microfone via SCK:

Configurar um SCStream para capturar áudio do sistema (adicionando um output do tipo .audio) e áudio do microfone (definindo captureMicrophone = true e adicionando um output do tipo .microphone) simultaneamente. O SCStreamDelegate receberá CMSampleBuffers separados para cada tipo de áudio.5



Opção de Mixagem 1: Usando AVAudioEngine:

Converter os CMSampleBuffers de áudio do sistema e de microfone para AVAudioPCMBuffers. Uma extensão em CMSampleBuffer para realizar essa conversão é mostrada em 41; embora o contexto original seja diferente, a lógica de acesso aos dados e criação do AVAudioPCMBuffer pode ser adaptada.
Utilizar dois AVAudioSourceNodes para alimentar esses AVAudioPCMBuffers (um para o áudio do sistema, outro para o áudio do microfone) no AVAudioEngine.
Mixar usando o mainMixerNode ou um AVAudioMixerNode customizado.
Obter a saída mixada através de um tap no nó do mixer.



Opção de Mixagem 2: Mixagem Manual de CMSampleBuffer (Avançado e Não Recomendado para Simplicidade):

Extrair os AudioBufferLists dos CMSampleBuffers de áudio do sistema e do microfone.13
Realizar a mixagem manual dos dados de áudio (por exemplo, somando as amostras de cada buffer, aplicando normalização para evitar clipping). Este processo é complexo, propenso a erros e requer um entendimento profundo de formatos de áudio e processamento de sinais.
Criar um novo CMSampleBuffer contendo os dados de áudio mixados.



Prós: Utiliza uma única API (ScreenCaptureKit) para capturar ambas as fontes de áudio. Potencialmente mais fácil de sincronizar se o ScreenCaptureKit fornecer timestamps consistentes e alinhados para ambos os fluxos de áudio (embora 35 questione a facilidade de interfacear o synchronizationClock do SCK com AVAudioEngine). Suporta versões do macOS anteriores à 14.2.
Contras: A confiabilidade da captura de áudio do ScreenCaptureKit, especialmente para ambos os fluxos simultaneamente e em versões mais antigas do macOS, pode ser uma preocupação.13 A conversão de CMSampleBuffer para AVAudioPCMBuffer e a subsequente alimentação no AVAudioEngine (na Opção de Mixagem 1) adicionam etapas e potencial latência. A mixagem manual de CMSampleBuffers é significativamente complexa. 35 destaca explicitamente problemas de eco e sincronização ao usar ScreenCaptureKit com AVAudioEngine para esta finalidade.
Estratégia C: ScreenCaptureKit (Áudio do Sistema) + AVAudioEngine (Microfone e Mixagem)Uma abordagem híbrida que pode ser útil se o ScreenCaptureKit já estiver em uso para captura de tela ou para suportar versões do macOS anteriores à 14.2 para áudio do sistema.

Captura de Áudio do Sistema:

Utilizar ScreenCaptureKit com um output do tipo .audio para obter CMSampleBuffers do áudio do sistema (conforme Seção 3.2).



Captura de Áudio do Microfone:

Utilizar o inputNode do AVAudioEngine para capturar o áudio do microfone (conforme Seção 4.1).



Alimentando Áudio do Sistema (SCK) no AVAudioEngine:

Converter os CMSampleBuffers (do áudio do sistema via SCK) para AVAudioPCMBuffers.41
Utilizar um AVAudioSourceNode para injetar esses AVAudioPCMBuffers no grafo do AVAudioEngine.



Mixagem:

Conectar o AVAudioSourceNode (com áudio do sistema) e o inputNode (microfone) ao mainMixerNode do AVAudioEngine ou a um AVAudioMixerNode customizado.
Obter a saída mixada através de um tap no nó do mixer.



Prós: Permite usar a robusta captura de microfone do AVAudioEngine. Utiliza ScreenCaptureKit para áudio do sistema, o que pode ser vantajoso se o SCK já estiver implementado para captura de tela ou se for necessário suportar versões do macOS que não possuem Core Audio Taps.
Contras: Combina as complexidades de ambas as APIs. Os desafios de sincronização entre os dados de áudio do ScreenCaptureKit e os do AVAudioEngine persistem e podem ser significativos.35
Considerações sobre Sincronização:A sincronização continua sendo o desafio mais formidável em todos os pipelines propostos.22 O AVAudioEngine cria internamente um dispositivo agregado privado que tenta realizar compensação de latência, mas sua eficácia pode ser limitada quando lida com fontes externas ou taps complexos.22 A Apple, em algumas discussões, sugeriu que a calibração manual por parte do aplicativo pode ser necessária para alcançar uma sincronia perfeita em certos cenários.22Uma observação interessante em 35 sugere que a API CATap (Core Audio Tap), quando usada para capturar tanto o áudio do sistema quanto o do microfone (possivelmente configurando um dispositivo agregado que inclua o microfone físico e o tap de sistema como suas fontes), pode lidar melhor com a sincronização e a correção de desvio (drift) entre os fluxos. Isso reforçaria a Estratégia A para macOS 14.2+, mas a implementação exata de como o "microfone" é integrado nesse cenário de CATap para sincronização ideal precisaria de investigação detalhada. Uma abordagem pragmática, também sugerida em 35, é realizar a mixagem em um AVAudioEngine configurado para operar offline (não em tempo real), após a captura dos fluxos e um trimming inicial dos buffers para alinhá-los grosseiramente. Isso pode mitigar alguns dos desafios da sincronização em tempo real.Não existe uma solução única que se adeque perfeitamente a todos os cenários. A escolha do pipeline mais apropriado dependerá fortemente da versão mínima do macOS que o aplicativo precisa suportar, da familiaridade do desenvolvedor com as APIs de baixo e alto nível da Apple, e da tolerância à complexidade inerente, especialmente no que diz respeito à sincronização. O AVAudioSourceNode desempenha um papel crucial como a "ponte" para introduzir fontes de áudio capturadas externamente (como de Core Audio Taps ou ScreenCaptureKit) no ambiente de processamento e mixagem do AVAudioEngine.21 Dominar seu uso é essencial para implementar as estratégias A e C, e a opção de mixagem 1 da Estratégia B.6. Escrevendo o Áudio Mixado em um ArquivoUma vez que o áudio do sistema e do microfone tenham sido capturados e mixados (presumivelmente resultando em um fluxo de AVAudioPCMBuffers do AVAudioEngine), a etapa final é salvar esse áudio combinado em um arquivo. AVFoundation oferece duas classes principais para esta tarefa: AVAudioFile e AVAssetWriter.Opção 1: Usando AVAudioFileAVAudioFile é ideal para cenários onde se está trabalhando diretamente com AVAudioPCMBuffers, que é o formato de saída comum de um tap no mainMixerNode do AVAudioEngine.
Funcionamento: Simplifica a escrita de buffers PCM em um arquivo de áudio.
Inicialização:
Um objeto AVAudioFile é inicializado para escrita usando o construtor init(forWriting:settings:commonFormat:interleaved:).42

forWriting fileURL: A URL do arquivo de saída.
settings: Um dicionário `` que especifica o formato do arquivo no disco (e.g., PCM linear, AAC) e seus parâmetros (taxa de amostragem, número de canais, profundidade de bits, taxa de bits do encoder, qualidade, etc.).11
commonFormat: O formato dos AVAudioPCMBuffers que serão escritos (e.g., .pcmFormatFloat32). Este deve corresponder ao formato dos buffers provenientes do AVAudioEngine.
interleaved: Um booleano indicando se os dados nos AVAudioPCMBuffers estão em formato interleaved ou non-interleaved.


Escrita:
Após a inicialização, os AVAudioPCMBuffers mixados são escritos sequencialmente no arquivo usando o método audioFile.write(from: buffer).7
Prós: É uma API de alto nível, simples e direta para escrever AVAudioPCMBuffers. Requer menos código de configuração em comparação com AVAssetWriter.
Contras: Menos flexível se for necessário um controle mais fino sobre o processo de escrita, ou se os dados de áudio estiverem em formato CMSampleBuffer e não tiverem sido processados pelo AVAudioEngine para mixagem.
Opção 2: Usando AVAssetWriterAVAssetWriter é uma API mais poderosa e flexível, adequada para cenários mais complexos, como a escrita de múltiplas trilhas (e.g., áudio e vídeo) ou quando os dados de origem estão em formato CMSampleBuffer.
Funcionamento: Permite a construção de arquivos de mídia a partir de amostras de mídia.
Configuração:

Inicializa-se um AVAssetWriter com a URL de saída e o tipo de arquivo (e.g., .mov, .mp4).12
Cria-se um AVAssetWriterInput para a trilha de áudio, especificando mediaType:.audio e um dicionário outputSettings similar ao usado com AVAudioFile para definir o formato de áudio da trilha.
O AVAssetWriterInput de áudio é então adicionado ao AVAssetWriter.


Escrita:

A sessão de escrita é iniciada com writer.startWriting() seguido por writer.startSession(atSourceTime:.zero) (ou um timestamp específico).
Os buffers de áudio são anexados ao AVAssetWriterInput usando assetWriterInput.append(sampleBuffer). Se os dados de áudio mixados estiverem como AVAudioPCMBuffers do AVAudioEngine, eles precisarão ser convertidos para CMSampleBuffer antes de serem anexados, o que adiciona complexidade. Se as fontes originais (sistema, microfone) foram capturadas como CMSampleBuffers (e.g., via ScreenCaptureKit) e mixadas manualmente (o que é complexo), o CMSampleBuffer resultante pode ser usado aqui.
Após todas as amostras terem sido anexadas, o input é marcado como finalizado (assetWriterInput.markAsFinished()), e a escrita do arquivo é concluída com writer.finishWriting().


Mixagem Prévia: É crucial entender que AVAssetWriter espera uma única AVAssetWriterInput para a trilha de áudio que se deseja no arquivo final. Se houver múltiplas fontes de áudio (e.g., CMSampleBuffers separados para áudio do sistema e microfone) e elas não foram previamente mixadas (e.g., pelo AVAudioEngine), alimentar múltiplas AVAssetWriterInput de áudio resultará em um arquivo com múltiplas trilhas de áudio separadas, não uma única trilha mixada.12 Portanto, a mixagem deve ocorrer antes de fornecer os dados ao AVAssetWriterInput.
Prós: Altamente flexível, ideal para cenários de áudio e vídeo combinados, e lida nativamente com CMSampleBuffers.
Contras: Significativamente mais complexo de configurar e gerenciar em comparação com AVAudioFile. Se a saída do pipeline de mixagem for AVAudioPCMBuffer, a conversão para CMSampleBuffer para uso com AVAssetWriterInput é uma etapa adicional.
Se o pipeline de mixagem utiliza AVAudioEngine e a saída final são AVAudioPCMBuffers (por exemplo, obtidos de um tap no mainMixerNode), AVAudioFile representa o caminho mais curto e simples para a escrita em arquivo.7 Isso geralmente resulta em menos código boilerplate e é mais direto para um caso de uso puramente de áudio. AVAssetWriter, por outro lado, brilha em cenários onde o áudio já está no formato CMSampleBuffer (e devidamente mixado) ou quando há uma trilha de vídeo a ser incluída no mesmo arquivo. Dada a complexidade da mixagem manual de CMSampleBuffers, e o fato de que AVAudioEngine é o método preferido para mixagem, AVAudioFile é frequentemente a escolha mais pragmática para salvar o resultado de um AVAudioEngine.Tabela: Formatos de Saída de Áudio e Configurações (para AVAudioFile / AVAssetWriter outputSettings)Parâmetro de ConfiguraçãoValor para PCM Linear (.caf, .wav)Valor para AAC (.m4a, .mp4)DescriçãoAVFormatIDKeykAudioFormatLinearPCMkAudioFormatMPEG4AACEspecifica o codec de áudio.AVSampleRateKeyTaxa de amostragem desejada (e.g., 44100.0, 48000.0)Taxa de amostragem desejada (e.g., 44100.0, 48000.0)A taxa de amostragem do áudio em Hz.AVNumberOfChannelsKeyNúmero de canais (e.g., 1 para mono, 2 para estéreo)Número de canais (e.g., 1 para mono, 2 para estéreo)O número de canais de áudio.AVLinearPCMBitDepthKeyProfundidade de bits (e.g., 16, 24, 32)N/AA profundidade de bits para amostras PCM.AVLinearPCMIsBigEndianKeyfalse (para little-endian, comum) ou trueN/AEspecifica a endianness para amostras PCM.AVLinearPCMIsFloatKeytrue (para ponto flutuante) ou false (para inteiro)N/AEspecifica se as amostras PCM são de ponto flutuante ou inteiras.AVLinearPCMIsNonInterleavedKeyfalse (para interleaved) ou true (para non-interleaved)N/AEspecifica se os canais PCM estão interleaved ou non-interleaved.AVEncoderBitRateKeyN/ATaxa de bits em bps (e.g., 128000, 192000, 256000)A taxa de bits para encoders com perdas como AAC.AVEncoderAudioQualityKeyN/AAVAudioQuality.min.rawValue, .low.rawValue, .medium.rawValue, .high.rawValue, .max.rawValueChave para definir a qualidade do encoder, resultando em diferentes taxas de bits se não especificadas.Nota: As configurações exatas podem depender do formato de arquivo específico (extensão) e das capacidades do sistema.7. Resumo da Compatibilidade de Versões do macOSA viabilidade de cada abordagem de captura e mixagem de áudio está intrinsecamente ligada à versão do macOS em execução. As APIs evoluíram, com novas funcionalidades sendo adicionadas e outras se tornando mais robustas ao longo do tempo.

Core Audio Taps:

Esta API, fundamental para a captura de áudio do sistema de forma granular e de baixo nível, requer macOS 14.2 ou posterior.3 Esta é uma limitação significativa se o aplicativo precisar suportar versões mais antigas do sistema operacional.



ScreenCaptureKit:

A funcionalidade geral do ScreenCaptureKit está disponível a partir do macOS 12.3.18
Para captura de áudio do sistema, aplicações como o Ecamm Live começaram a utilizá-lo no macOS 13 e posterior.17 Um desenvolvedor mencionou o uso no macOS 13, mas com planos de migrar para Core Audio Taps, o que implicaria abandonar o suporte ao macOS 13 para essa funcionalidade específica.23
A capacidade de captura de microfone (captureMicrophone, microphoneCaptureDeviceID) é referenciada em contextos do macOS 15 ou posterior para certas funcionalidades avançadas como salvamento direto em arquivo 5, embora a propriedade captureMicrophone em si possa estar disponível em versões um pouco anteriores. No entanto, problemas de implementação e confiabilidade foram observados.5
Problemas de estabilidade e bugs, como o erro SCStreamErrorDomain Code=-3805 ou a ausência de callbacks de áudio, foram relatados em versões beta do macOS 15 13, indicando que a API ainda pode estar amadurecendo em relação a certos casos de uso de áudio.



AVFoundation (AVAudioEngine):

O AVAudioEngine e seus componentes principais, como o AVAudioInputNode para captura de microfone, estão disponíveis desde o macOS 10.10 5, tornando-o uma escolha estável e amplamente compatível para essas tarefas.
O AVAudioSourceNode, crucial para injetar áudio de fontes customizadas (como Core Audio Taps ou ScreenCaptureKit) no AVAudioEngine, especificamente com o renderBlock que aceita um AudioTimeStamp, requer macOS 10.15 ou posterior.21


O macOS 14.2+ representa um ponto de inflexão para a captura de áudio do sistema de alta qualidade e de forma nativa. A introdução dos Core Audio Taps 3 preencheu uma lacuna importante, oferecendo uma API robusta e de baixo nível que anteriormente era atendida por soluções alternativas ou APIs menos diretas como o ScreenCaptureKit. Para novos projetos que podem definir o macOS 14.2+ como sua versão mínima, a combinação de Core Audio Taps para áudio do sistema e AVAudioEngine para microfone e mixagem é provavelmente a abordagem mais tecnicamente sólida e "future-proof".Para compatibilidade com versões do macOS anteriores à 14.2, o ScreenCaptureKit emerge como a principal API nativa com capacidade de capturar áudio do sistema.17 No entanto, sua utilização para áudio, especialmente áudio do sistema isolado ou áudio de microfone, deve ser feita com cautela. A confiabilidade pode variar, e relatos de instabilidade ou bugs, dependendo da versão específica do macOS, não são incomuns.13 Desenvolvedores que optam por esta rota devem alocar tempo para testes extensivos em diferentes configurações de sistema e estar preparados para implementar soluções alternativas para contornar possíveis problemas de comportamento inesperado.Tabela: Compatibilidade de Versões do macOS para Soluções PropostasSolução/PipelineComponente Chave para Áudio do SistemaComponente Chave para MicrofoneVersão Mínima Estimada do macOSObservaçõesCore Audio Taps (Sistema) + AVAudioEngine (Microfone/Mixagem)Core Audio TapsAVAudioEngine.inputNodemacOS 14.2+AVAudioSourceNode (com AudioTimeStamp no renderBlock) requer macOS 10.15+. Controle granular, API moderna para sistema.ScreenCaptureKit (Sistema e Microfone) + AVAudioEngine (Mixagem)ScreenCaptureKit (.audio)ScreenCaptureKit (.microphone)macOS 13+ (para áudio de sistema SCK mais estável), macOS 15+ (para algumas func. de mic SCK)AVAudioSourceNode (com AudioTimeStamp) requer macOS 10.15+. Requer permissão de tela. Confiabilidade do áudio SCK pode variar.ScreenCaptureKit (Sistema) + AVAudioEngine (Microfone/Mixagem)ScreenCaptureKit (.audio)AVAudioEngine.inputNodemacOS 13+ (para áudio de sistema SCK mais estável)AVAudioSourceNode (com AudioTimeStamp) requer macOS 10.15+. Combina robustez do mic de AVAudioEngine com SCK para sistema. Sincronização é um desafio.AVAudioFile (Escrita)N/AN/AmacOS 10.10+Depende do AVAudioEngine para fornecer buffers.AVAssetWriter (Escrita)N/AN/AmacOS 10.7+ (geral)Flexível, mas mais complexo.8. Checklist de Permissões e Configuração do App SandboxA configuração correta das permissões é um passo crítico e frequentemente uma fonte de problemas na captura de áudio. A falha em declarar as permissões necessárias ou em configurar o App Sandbox adequadamente pode resultar na falha silenciosa da captura de áudio, onde o aplicativo não recebe buffers de áudio e nenhum erro óbvio é lançado.5 A ausência de um prompt de permissão para o usuário é um forte indicador de um problema de configuração.Chaves do Info.plist:

NSMicrophoneUsageDescription (String):

Obrigatório para qualquer aplicativo que acesse a entrada do microfone.
Frameworks Relevantes: AVFoundation (AVAudioEngine), ScreenCaptureKit (captureMicrophone = true).
Exemplo de Valor: "Este aplicativo precisa de acesso ao microfone para gravar sua voz durante a captura de tela e áudio do sistema."
Referências: 5



NSAudioCaptureUsageDescription (String):

Obrigatório para aplicativos que capturam o áudio de saída do sistema usando Core Audio Taps.
Frameworks Relevantes: Core Audio (especificamente com AudioHardwareCreateProcessTap).
Exemplo de Valor: "Este aplicativo precisa de permissão para capturar o áudio do sistema para fins de gravação e mixagem com sua entrada de microfone."
Referências: 2



NSScreenCaptureDescription (String):

Geralmente necessário se ScreenCaptureKit for utilizado, mesmo que o objetivo principal seja apenas a captura de áudio, pois a permissão de "Gravação de Tela" é o portal de entrada para as funcionalidades deste framework.
Frameworks Relevantes: ScreenCaptureKit.
Exemplo de Valor: "Este aplicativo precisa de permissão para gravar a tela e o áudio do sistema para criar suas gravações."


Entitlements do App Sandbox (se o aplicativo for sandboxed):Se o aplicativo for distribuído através da Mac App Store ou optar por utilizar o App Sandbox por razões de segurança, os seguintes entitlements devem ser configurados na aba "Signing & Capabilities" do Xcode 50:

com.apple.security.app-sandbox (Boolean):

Deve ser definido como true.



Hardware > Audio Input (com.apple.security.device.audio-input) (Boolean):

Necessário para permitir que um aplicativo sandboxed acesse o microfone.
Frameworks Relevantes: AVFoundation (AVAudioEngine), ScreenCaptureKit (captureMicrophone = true).
Referências: 5



com.apple.security.system.audio-input (Boolean):

Este entitlement é especificamente mencionado em fontes da comunidade 2 como necessário para a captura de áudio do sistema por um aplicativo sandboxed, especialmente ao usar Core Audio Taps. A documentação oficial da Apple para Core Audio Taps 3 foca na chave NSAudioCaptureUsageDescription e no prompt do sistema, mas para um aplicativo sandboxed, um entitlement correspondente é tipicamente o mecanismo que concede acesso a recursos protegidos.
Frameworks Relevantes: Core Audio (com AudioHardwareCreateProcessTap).



App Data > Screen Capture (com.apple.security.screencapture) (Boolean ou String):

Necessário se ScreenCaptureKit for utilizado para qualquer tipo de captura (tela, janela, áudio do sistema, áudio do microfone). O valor pode ser um booleano ou uma string especificando o modo (window, display, audio).


É importante notar que os entitlements para captura de áudio do sistema são, por vezes, menos documentados centralmente em comparação com os de microfone. Portanto, desenvolvedores que utilizam Core Audio Taps em um ambiente sandboxed devem prestar atenção especial ao entitlement com.apple.security.system.audio-input ou equivalentes, além da chave Info.plist, para garantir o funcionamento correto.Tabela: Resumo de PermissõesTipo de CapturaChave Info.plist RequeridaEntitlement App Sandbox (se aplicável)Frameworks RelevantesObservaçõesÁudio do MicrofoneNSMicrophoneUsageDescriptioncom.apple.security.device.audio-inputAVFoundation (AVAudioEngine), ScreenCaptureKitEssencial para qualquer acesso ao microfone.Áudio do Sistema (Core Audio Taps)NSAudioCaptureUsageDescriptioncom.apple.security.system.audio-inputCore AudioEspecífico para macOS 14.2+. O entitlement é crucial para apps sandboxed.Áudio do Sistema (ScreenCaptureKit)NSScreenCaptureDescription (primário)com.apple.security.screencapture (com audio)ScreenCaptureKitA permissão de gravação de tela é o gatilho. NSAudioCaptureUsageDescription pode ser complementar, mas não é o foco principal da API SCK.Captura de Tela (ScreenCaptureKit)NSScreenCaptureDescriptioncom.apple.security.screencaptureScreenCaptureKitPermissão base para usar ScreenCaptureKit.9. Recomendações e Melhores PráticasA implementação bem-sucedida da gravação e mixagem de áudio do sistema e do microfone no macOS requer não apenas a escolha correta das APIs, mas também uma atenção cuidadosa a diversos aspectos práticos, desde o tratamento de erros até a experiência do usuário e o gerenciamento de recursos.

Escolhendo a Abordagem Correta:

A decisão fundamental sobre qual pipeline adotar deve ser guiada pela versão mínima do macOS que o aplicativo precisa suportar. Para projetos que podem ter como alvo o macOS 14.2 ou posterior, a combinação de Core Audio Taps para captura de áudio do sistema e AVAudioEngine para captura de microfone e mixagem (Estratégia A da Seção 5) é uma forte candidata. Esta abordagem oferece controle granular e utiliza as APIs mais modernas e diretas para cada tarefa.
Para garantir compatibilidade com versões anteriores do macOS (anteriores à 14.2), o ScreenCaptureKit (para áudio do sistema e, potencialmente, microfone) em conjunto com o AVAudioEngine (para microfone, se não usado via SCK, e para mixagem – Estratégias B ou C da Seção 5) torna-se a principal rota nativa. No entanto, é crucial estar ciente das ressalvas sobre a estabilidade e os possíveis comportamentos inesperados do ScreenCaptureKit para captura de áudio em versões mais antigas.



Tratamento de Erros e Casos Extremos:

Verificação de OSStatus: Todas as chamadas para funções do Core Audio retornam um OSStatus. É imperativo verificar esses códigos de retorno e tratar quaisquer erros apropriadamente.
Erros de AVAudioEngine: A inicialização e o início do AVAudioEngine (try audioEngine.start()) podem falhar por diversos motivos (e.g., problemas com o dispositivo de áudio, configuração inválida). Esses erros devem ser capturados e tratados.6
Erros de SCStream: Similarmente, o início de um SCStream (try stream.startCapture()) pode falhar. O bloco catch deve lidar com essas exceções.5
Mudanças de Dispositivo de Áudio: O sistema de áudio do macOS é dinâmico. Microfones podem ser desconectados, ou o dispositivo de saída padrão pode mudar durante a gravação. O aplicativo deve ser capaz de lidar graciosamente com essas mudanças. 2 discute em detalhe o monitoramento e tratamento de mudanças de dispositivo no contexto de Core Audio Taps. Para AVAudioEngine, notificações como AVAudioEngineConfigurationChange podem ser observadas.
Revogação de Permissões: O usuário pode revogar as permissões de gravação de áudio ou tela a qualquer momento através das Preferências do Sistema. O aplicativo deve detectar essa mudança (e.g., verificando o status da autorização periodicamente ou ao tentar iniciar uma nova captura) e reagir de forma apropriada, possivelmente parando a gravação e informando o usuário.



Comunicação com o Usuário:

A experiência do usuário em relação às permissões é crucial, dado o quão sensível é a captura de áudio, especialmente do sistema.
Feedback de Gravação: Fornecer um feedback visual claro e persistente quando a gravação está ativa é essencial para a transparência.
Justificativa de Permissões: As mensagens fornecidas nas chaves NSMicrophoneUsageDescription, NSAudioCaptureUsageDescription e NSScreenCaptureDescription do Info.plist devem ser claras, concisas e explicar honestamente por que o acesso é necessário.
Seleção de Dispositivo: Se o aplicativo permitir, oferecer uma interface para que o usuário selecione os dispositivos de entrada de áudio (microfone) pode melhorar a usabilidade.



Gerenciamento de Threads e Performance:

Callbacks de áudio, como IOProcs do Core Audio, taps instalados no AVAudioEngine (inputNode, mainMixerNode), e o método stream(_:didOutputSampleBuffer:ofType:) do SCStreamDelegate, são frequentemente invocados em threads de alta prioridade e sensíveis ao tempo.
É fundamental evitar qualquer trabalho bloqueador, demorado ou que possa alocar memória de forma irrestrita dentro desses callbacks para não causar interrupções, latência ou instabilidade no áudio.2
Tarefas como processamento de áudio pesado, compressão, ou escrita em arquivo devem ser despachadas para filas de processamento em segundo plano (background queues) para não impactar o thread de áudio em tempo real.



Limpeza de Recursos:

O gerenciamento adequado do ciclo de vida dos objetos de áudio é fundamental para a estabilidade do aplicativo e do sistema. A falha em configurar, iniciar, parar e liberar corretamente esses objetos pode levar a vazamentos de memória, crashes, ou comportamento inesperado do subsistema de áudio do macOS.6
AVAudioEngine: Deve ser parado (engine.stop()) e, se necessário, reinicializado (engine.reset()) quando não estiver mais em uso ou antes de reconfigurações.
Taps do AVAudioEngine: Devem ser removidos usando removeTap(onBus:) quando não forem mais necessários.
SCStream: Deve ser parado com stream.stopCapture() quando a captura não for mais desejada.
Core Audio Objects: Core Audio Taps e Dispositivos Agregados criados programaticamente devem ser destruídos usando AudioHardwareDestroyProcessTap e AudioHardwareDestroyAggregateDevice, respectivamente, para liberar os recursos do sistema.3
AVAudioFile: Arquivos abertos para escrita devem ser devidamente fechados (o AVAudioFile não possui um método close() explícito, seu deinit lida com isso, mas garantir que todas as escritas pendentes sejam concluídas e que o objeto saia do escopo corretamente é importante).


10. ConclusãoA tarefa de gravar e mixar áudio do sistema e do microfone nativamente no macOS utilizando Swift 5.9 é complexa, mas factível através da combinação estratégica dos frameworks fornecidos pela Apple.Sumário das Descobertas:Este relatório analisou três frameworks principais:
Core Audio: Oferece o controle de mais baixo nível, sendo essencial para a captura de áudio do sistema através de "Audio Taps" no macOS 14.2 e posterior. Sua implementação é complexa, mas poderosa.
AVFoundation: Provê o AVAudioEngine, uma ferramenta robusta e de nível mais alto, ideal para a captura de áudio do microfone, mixagem de múltiplas fontes de áudio e escrita em arquivos através do AVAudioFile. É amplamente compatível com versões mais antigas do macOS.
ScreenCaptureKit: Primariamente um framework de captura de tela, também pode capturar áudio do sistema e do microfone. É uma alternativa para áudio do sistema em versões do macOS anteriores à 14.2, mas sua confiabilidade para áudio puro pode variar e requer permissão de gravação de tela.
Recomendação Final do Pipeline:A escolha do pipeline ideal depende crucialmente da versão mínima do macOS a ser suportada:
Para macOS 14.2 e posterior: A abordagem mais robusta e tecnicamente elegante é utilizar Core Audio Taps para capturar o áudio do sistema e o AVAudioEngine para capturar o áudio do microfone. O áudio do sistema capturado (como AudioBufferList) deve ser convertido para AVAudioPCMBuffer e injetado no AVAudioEngine através de um AVAudioSourceNode. O AVAudioEngine então lida com a mixagem e a saída pode ser gravada usando AVAudioFile.
Para compatibilidade com versões do macOS anteriores à 14.2 (e.g., macOS 13): O ScreenCaptureKit torna-se a principal opção nativa para captura de áudio do sistema. O áudio do microfone pode ser capturado tanto pelo ScreenCaptureKit (com ressalvas sobre sua estabilidade e requisitos de permissão) quanto, preferencialmente, pelo AVAudioEngine. Se ambas as fontes forem capturadas como CMSampleBuffers (via SCK) ou convertidas para AVAudioPCMBuffers, elas podem ser alimentadas no AVAudioEngine usando AVAudioSourceNodes para mixagem, e a saída gravada com AVAudioFile. Esta abordagem exige atenção redobrada aos desafios de sincronização e potenciais instabilidades do ScreenCaptureKit para áudio.
Principais Desafios Reafirmados:Independentemente da abordagem, três desafios principais persistem:
Sincronização: Alinhar temporalmente os fluxos de áudio do sistema e do microfone é a tarefa mais complexa, exigindo um gerenciamento cuidadoso de timestamps e latências.
Gerenciamento de Permissões: A configuração correta das chaves do Info.plist e dos entitlements do App Sandbox é crucial e uma fonte comum de falhas.
Complexidade da API de Baixo Nível: A interação com Core Audio, e mesmo partes do AVAudioEngine para seleção de dispositivos ou uso de AVAudioSourceNode, requer um entendimento técnico aprofundado.
Próximos Passos para o Desenvolvedor:Recomenda-se que o desenvolvedor realize testes exaustivos em diferentes versões do macOS e configurações de hardware para validar a solução escolhida. A consulta aos exemplos de código da Apple (especialmente para Core Audio Taps e ScreenCaptureKit) e a projetos de código aberto referenciados neste relatório (como AudioCap) pode fornecer insights práticos valiosos. A prototipagem incremental, começando com a captura de cada fonte individualmente antes de tentar a mixagem e sincronização, é uma estratégia prudente.Considerações Futuras:As APIs de áudio da Apple continuam a evoluir. É provável que futuras versões do macOS tragam melhorias na facilidade de uso, robustez e capacidades de sincronização para cenários complexos de captura e processamento de áudio. Manter-se atualizado com a documentação da Apple e as sessões da WWDC é essencial para aproveitar os avanços futuros.Em suma, embora desafiador, o desenvolvimento de uma solução nativa para gravação e mixagem de áudio do sistema e microfone no macOS é uma empreitada recompensadora, abrindo um leque de possibilidades para aplicações inovadoras e ricas em funcionalidades.



#Research 2

# Gravação de áudio nativa no macOS com Swift 5.9

As capacidades nativas do macOS para gravação simultânea de áudio do sistema e microfone passaram por uma revolução significativa com a introdução do **ScreenCaptureKit no macOS 12.3 (março de 2022)**, oferecendo pela primeira vez suporte nativo robusto para captura de áudio do sistema. Esta análise técnica abrangente examina as implementações disponíveis, desafios de sincronização e pipeline completo para mixagem em tempo real utilizando Swift 5.9.

## ScreenCaptureKit revoluciona a captura de áudio do sistema

O **ScreenCaptureKit representa o maior avanço** nas capacidades nativas de captura de áudio do sistema no macOS desde o lançamento da plataforma. Disponível no macOS 12.3+ (Monterey e versões posteriores), este framework elimina a necessidade de soluções alternativas complexas como BlackHole ou Soundflower que eram previamente necessárias.

**Versões compatíveis e evolução das funcionalidades:**
- **macOS 12.3+**: Introdução básica do ScreenCaptureKit
- **macOS 13+ (Ventura)**: Melhorias significativas de performance e funcionalidades expandidas  
- **macOS 14+ (Sonoma)**: Introdução da API CATap para captura de áudio específica de processos
- **macOS 15+ (Sequoia)**: Adição de captura de microfone integrada via `captureMicrophone` e `microphoneCaptureDeviceID`

As versões anteriores ao macOS 12.3 requeriam workarounds complexos com dispositivos de áudio virtuais, pois o `AVCaptureScreenInput` (agora descontinuado) não incluía suporte para captura de áudio do sistema.

## APIs fundamentais para implementação em Swift 5.9

### ScreenCaptureKit: A API principal moderna

O ScreenCaptureKit oferece uma arquitetura robusta centrada em cinco componentes principais:

**SCStream** serve como a classe central de streaming para capturar conteúdo de tela e áudio. **SCShareableContent** enumera displays, janelas e aplicações disponíveis para captura. **SCContentFilter** define precisamente qual conteúdo capturar (baseado em display ou janela específica). **SCStreamConfiguration** configura parâmetros de áudio/vídeo incluindo taxa de amostragem (até 48kHz estéreo), contagem de canais e formato. **SCStreamOutput** implementa o protocolo para receber amostras de áudio como CMSampleBuffers.

```swift
import ScreenCaptureKit

@MainActor
class AudioCapture: NSObject, SCStreamDelegate, SCStreamOutput {
    private var stream: SCStream?
    
    func startSystemAudioCapture() async throws {
        let content = try await SCShareableContent.getShareableContent()
        let filter = SCContentFilter(display: content.displays.first!, 
                                   excludingWindows: [])
        
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.sampleRate = 48000
        config.channelCount = 2
        
        stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream?.addStreamOutput(self, type: .audio, sampleHandlerQueue: .global())
        try await stream?.startCapture()
    }
    
    nonisolated func stream(_ stream: SCStream, 
                           didOutputSampleBuffer sampleBuffer: CMSampleBuffer, 
                           of type: SCStreamOutputType) {
        // Processar amostras de áudio
    }
}
```

A granularidade de captura opera **ao nível da aplicação** - ao capturar uma janela, todo o áudio dessa aplicação é capturado, mas não é possível isolar áudio de janelas individuais dentro da mesma aplicação.

### CoreAudio: Framework de baixo nível para controle avançado

O CoreAudio fornece **APIs de abstração de hardware** através do AudioHardware e framework Audio Unit para acesso direto aos dispositivos de áudio. A **nova API CATap (macOS 14.4+)** permite captura de áudio de processos ou grupos de processos específicos, oferecendo controle mais refinado mas com implementação significativamente mais complexa baseada em C.

### AVFoundation: Limitado para áudio do sistema, essencial para microfone

O AVFoundation tem **suporte limitado para áudio do sistema**, sendo primariamente adequado para captura de microfone via `AVAudioEngine.inputNode`. O `AVCaptureScreenInput` foi descontinuado em favor do ScreenCaptureKit e não suportava áudio do sistema.

## Implementação robusta de captura de microfone com AVFoundation

O **AVAudioEngine** fornece uma arquitetura poderosa de processamento de áudio baseada em grafos de nós conectados em cadeias de processamento. A arquitetura fundamental inclui três tipos de nós: **nós fonte** (AVAudioPlayerNode, AVAudioInputNode), **nós de processamento** (AVAudioMixerNode, AVAudioUnitEffect), e **nós de destino** (AVAudioOutputNode).

```swift
let engine = AVAudioEngine()
let inputNode = engine.inputNode
let inputFormat = inputNode.inputFormat(forBus: 0)

// Instalar tap para capturar dados de áudio
inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { buffer, time in
    // Processar buffer de áudio do microfone
    // buffer contém dados PCM de áudio
}

try engine.start()
```

**Considerações importantes** incluem a necessidade de permissão de microfone e configuração adequada do Info.plist no macOS. O AVAudioInputNode está **fixo ao dispositivo de entrada padrão do sistema** e o formato de entrada é determinado pelas configurações de hardware e sistema.

## Técnicas avançadas de mixagem e sincronização

### Desafio da sincronização: Domínios de relógio diferentes

O **maior desafio técnico** reside na sincronização entre ScreenCaptureKit e AVAudioEngine, que utilizam referências de relógio diferentes, levando a drift e problemas de eco. A solução envolve sincronização baseada em Host Time:

```swift
class AudioSynchronizer {
    private var initialHostTime: UInt64 = 0
    
    func synchronizeStreams(systemBuffer: CMSampleBuffer, micBuffer: AVAudioPCMBuffer, micTime: AVAudioTime) {
        // Extrair host time do áudio do sistema
        let systemHostTime = CMSampleBufferGetPresentationTimeStamp(systemBuffer).hostTime
        let micHostTime = micTime.hostTime
        
        if initialHostTime == 0 {
            initialHostTime = min(systemHostTime, micHostTime)
        }
        
        // Calcular offsets relativos e aplicar compensação
        let timeDifference = Int64(systemHostTime - initialHostTime) - Int64(micHostTime - initialHostTime)
        let frameDifference = AVAudioFramePosition(timeDifference * Int64(outputFormat.sampleRate) / 1_000_000_000)
        
        alignBuffers(systemBuffer: systemBuffer, micBuffer: micBuffer, offsetFrames: frameDifference)
    }
}
```

### AVAudioMixerNode para combinação de fluxos de áudio

O **AVAudioMixerNode** serve como componente essencial para combinar múltiplas entradas em uma única saída, suportando controle individual de volume por entrada e conversões de formato automáticas:

```swift
let mixerNode = AVAudioMixerNode()
let systemPlayerNode = AVAudioPlayerNode()

engine.attach(mixerNode)
engine.attach(systemPlayerNode)

// Conectar múltiplas fontes ao mixer
engine.connect(engine.inputNode, to: mixerNode, format: inputFormat)
engine.connect(systemPlayerNode, to: mixerNode, format: systemFormat)
engine.connect(mixerNode, to: engine.outputNode, format: outputFormat)

// Controlar volumes individuais
mixerNode.outputVolume = 0.8 // Volume master de saída
```

## Pipeline completo para captura simultânea e mixagem

### Arquitetura de pipeline proposta

**Fase 1: Inicialização e configuração**
```swift
// Configurar sessão de áudio
let audioSession = AVAudioSession.sharedInstance()
try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])

// Inicializar ScreenCaptureKit  
let config = SCStreamConfiguration()
config.capturesAudio = true
config.sampleRate = 48000  // Será convertido para 16kHz posteriormente

// Configurar grafo AVAudioEngine
// Input Node → Converter → Mixer → Output Converter → Tap
```

**Fase 2: Processamento de captura e conversão**
O pipeline processa áudio do sistema via ScreenCaptureKit (recebendo CMSampleBuffer e convertendo para AVAudioPCMBuffer) simultaneamente com captura de microfone via tap do AVAudioEngine inputNode, aplicando conversão de formato conforme necessário.

**Fase 3: Sincronização e mixagem em tempo real**
Implementa alinhamento temporal extraindo host time de ambas as fontes, calcula offset e aplica compensação, realizando mixagem ao nível de amostra com controle de ganho e mapeamento de canais.

**Fase 4: Gravação e normalização para 16kHz**

```swift
class AudioFormatConverter {
    func setupConverters(systemFormat: AVAudioFormat, micFormat: AVAudioFormat) {
        let targetFormat = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        
        systemAudioConverter = AVAudioConverter(from: systemFormat, to: targetFormat)
        systemAudioConverter?.sampleRateConverterAlgorithm = .normal
        systemAudioConverter?.sampleRateConverterQuality = .high
        
        microphoneConverter = AVAudioConverter(from: micFormat, to: targetFormat)
    }
}
```

### Implementação de gravação para formatos AAC e PCM

**AVAudioFile** é recomendado para gravação somente de áudio:
```swift
let settings: [String: Any] = [
    AVFormatIDKey: Int(kAudioFormatLinearPCM),
    AVSampleRateKey: 16000.0,
    AVNumberOfChannelsKey: 1,
    AVLinearPCMBitDepthKey: 16,
    AVLinearPCMIsFloatKey: false
]

let audioFile = try AVAudioFile(forWriting: audioFilename, settings: settings)
try audioFile.write(from: mixedAudioBuffer)
```

**AVAssetWriter** oferece controle avançado para mídia complexa:
```swift
let audioSettings: [String: Any] = [
    AVFormatIDKey: kAudioFormatMPEG4AAC,
    AVNumberOfChannelsKey: 1,
    AVSampleRateKey: 16000.0,
    AVEncoderBitRateKey: 64000  // Otimizado para 16kHz
]
```

## Limitações críticas e desafios de implementação

### Permissões de privacidade e segurança

O **macOS Mojave 10.14+** introduziu consentimento obrigatório do usuário para gravação de tela e captura de áudio do sistema. Apps devem ser explicitamente autorizados antes de acessar fluxos de áudio do sistema através das configuraçoes de **Privacidade e Segurança > Gravação de Tela e Áudio do Sistema**.

**Problemas conhecidos** incluem solicitações de permissão recorrentes mesmo após aprovação inicial (especialmente no macOS Sonoma 14.4+), revogação automática de permissões se apps são percebidos como contornando controles de segurança, e perda de permissões de áudio ao transitar entre estados foreground/background.

### Gerenciamento de latência e considerações de performance

**Otimização crítica de performance** requer uso de buffer pools para evitar alocações frequentes, minimização de conversões de formato em threads de tempo real, pré-alocação de instâncias de conversor durante configuração, e uso de prioridades de queue apropriadas (`.userInteractive` para áudio).

**Desafios de latência** incluem diferentes relógios de sincronização entre ScreenCaptureKit e AVFoundation, discrepâncias de timestamp onde CMSampleBuffer do ScreenCaptureKit pode não alinhar com timestamps do AVAudioEngine, e latência de conversão de buffer ao converter CMSampleBuffer para AVAudioPCMBuffer descartando timestamps originais.

### Limitações específicas de hardware e plataforma

**Restrições de hardware** significativas incluem AirPods Pro limitados a taxa máxima de gravação de 16kHz (significativamente menor que microfone built-in a 44.1kHz), problemas de compatibilidade de driver com algumas interfaces de áudio USB em Macs Apple Silicon, e latência e degradação de qualidade adicional com dispositivos de áudio Bluetooth.

**Bugs críticos conhecidos** incluem crashes confirmados no macOS 14.7.3 com EXC_BAD_ACCESS em swift_getErrorValue durante tratamento de erro, falhas no `getShareableContentWithCompletionHandler` que podem levar 40+ segundos em chips M3 com certas aplicações, e necessidade de reinicialização do serviço replayd para recuperar de falhas de múltiplos streams.

### Modificação de sample rate e considerações de qualidade

A **capacidade de normalização para 16kHz** é totalmente suportada através do AVAudioConverter com configurações de alta qualidade. **Estratégias de otimização** incluem correspondência de taxas de amostragem de hardware para evitar reamostragem interna, uso de algoritmos de conversão de alta qualidade (`.high` quality setting), e implementação de interpolação linear ou Lagrange customizada para melhor qualidade que reamostragem do sistema.

## Recomendações para implementação prática

**Abordagem híbrida recomendada**: Utilizar ScreenCaptureKit para áudio do sistema e AVAudioEngine para entrada de microfone, implementando tratamento robusto de erro para bugs conhecidos do ScreenCaptureKit, incluindo monitoramento de performance (CPU, memória, thermal), e fornecendo degradação graciosa para combinações hardware/software não suportadas.

**Matriz de teste essencial**: Teste abrangente através de versões do macOS, configurações de hardware e dispositivos de áudio, educação clara do usuário indicando requisitos de permissão e status de gravação, e atualizações regulares conforme Apple lança novas versões do macOS e melhorias de framework.

A implementação bem-sucedida requer compreensão profunda tanto das capacidades quanto das limitações atuais, com planejamento cuidadoso para contornar restrições conhecidas e otimizar para diferentes cenários de hardware e software.