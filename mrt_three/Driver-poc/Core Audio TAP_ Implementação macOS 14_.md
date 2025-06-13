**Guia Técnico Detalhado: Captura de Áudio do Sistema no macOS 14 com
Core Audio TAP, SMJobBless e Helper Tool Privilegiada**

**I. Introdução**

A captura de áudio do sistema no macOS apresenta desafios significativos
devido às robustas políticas de segurança e à complexidade inerente do
framework Core Audio. Este documento técnico visa fornecer um guia
prático e detalhado para desenvolvedores sobre como implementar a
captura de áudio do sistema no macOS 14 (Sonoma), utilizando uma
arquitetura que envolve Core Audio Taps, o mecanismo SMJobBless para
instalação de uma Helper Tool privilegiada e XPC para comunicação
interprocessos segura. Esta abordagem, embora complexa, é necessária
para contornar as restrições que impedem aplicações padrão de acessarem
diretamente o áudio de outros processos ou do sistema como um todo.

Este guia destina-se a desenvolvedores com familiaridade em programação
para macOS, Swift e Objective-C/C. Serão abordados desde a configuração
do projeto no Xcode até a implementação detalhada da aplicação principal
e da helper tool, incluindo exemplos de código, configurações de
property lists e dicas de depuração. A metodologia aqui descrita é
particularmente relevante para macOS 14.2 e versões posteriores,
conforme indicado em documentações de referência da Apple sobre Core
Audio Taps.^1^

**II. Compreendendo a Arquitetura**

A captura de áudio do sistema em um ambiente seguro como o macOS requer
uma arquitetura multifacetada que respeite as políticas de segurança do
sistema operacional, ao mesmo tempo em que concede os privilégios
necessários para operações de baixo nível. A seguir, detalhamos os
componentes cruciais desta arquitetura.

**A. Core Audio TAP (Process Tap)**

Os Core Audio Taps, especificamente os \"Process Taps\", são um
mecanismo fornecido pelo Core Audio que permite capturar o áudio de
saída de um ou mais processos específicos.^1^ A criação de um tap é
realizada através da função AudioHardwareCreateProcessTap, que aceita
uma estrutura CATapDescription para configurar suas propriedades.^1^

Essas propriedades incluem a definição dos processos alvo, se o tap é
público (visível para todos os usuários) ou privado (visível apenas para
o processo criador) e opções de mixagem, como mono ou estéreo.^1^ Uma
característica importante é a capacidade de integrar um tap a um
dispositivo agregado (Aggregate Device). Isso permite que o áudio
capturado pelo tap seja tratado como uma entrada de áudio padrão no
sistema, similar a um microfone.^1^ Essa integração é fundamental para
que outras partes do sistema ou da aplicação possam consumir o áudio
capturado de forma padronizada.

**B. A Necessidade de uma Helper Tool Privilegiada**

Tentativas de utilizar AudioHardwareCreateProcessTap diretamente de uma
aplicação padrão, mesmo que esta não esteja em sandbox e possua o
entitlement com.apple.security.system-audio-capture, consistentemente
resultam no erro kAudioHardwareIllegalOperationError (representado
frequentemente pelo código de quatro caracteres \'what\').^3^ Este
comportamento ocorre porque as políticas de segurança do macOS são
projetadas para impedir que um processo de aplicação padrão acesse
diretamente o fluxo de áudio de um processo arbitrário e não
relacionado, independentemente do status de sandbox da aplicação
chamadora.^3^

O entitlement com.apple.security.system-audio-capture, quando aplicado a
uma aplicação padrão, parece não conceder os privilégios necessários
para esta chamada de API de baixo nível de forma direta.^3^ Observa-se
que implementações bem-sucedidas de captura de áudio de sistema, como a
aplicação AudioCap mencionada em discussões da comunidade, utilizam uma
ferramenta auxiliar separada e privilegiada (Helper Tool).^3^ Esta
helper tool é executada fora do contexto da aplicação principal,
geralmente lançada pelo launchd e instalada com privilégios elevados
através de mecanismos como SMJobBless. A helper tool é, então,
responsável por realizar as chamadas sensíveis do Core Audio. Este
modelo sugere que o macOS permite essas operações a partir de um
processo auxiliar validado e privilegiado, mas não de uma aplicação
comum.

**C. SMJobBless para Instalação e Gerenciamento da Helper Tool**

SMJobBless é a função do framework Service Management recomendada pela
Apple para instalar e registrar daemons e agentes que necessitam de
privilégios elevados.^5^ Este mecanismo substitui abordagens mais
antigas e menos seguras, como o uso de binários setuid ou a função
AuthorizationExecuteWithPrivileges (atualmente depreciada).^5^

Ao utilizar SMJobBless, a aplicação principal solicita ao sistema para
\"abençoar\" e instalar a helper tool. O sistema, por sua vez, realiza
uma série de verificações de segurança, crucialmente baseadas em
assinaturas de código (code signing).^5^ Tanto a aplicação principal
quanto a helper tool devem ser assinadas digitalmente, e suas
respectivas Info.plist devem conter requisitos de assinatura que
estabeleçam uma relação de confiança mútua. Se todas as verificações
forem bem-sucedidas, a helper tool é copiada para um local protegido
(tipicamente /Library/PrivilegedHelperTools) e seu launchd.plist
associado é registrado com launchd, permitindo que a helper tool seja
executada como root sob demanda.^5^

**D. XPC para Comunicação Interprocessos (IPC)**

XPC (Cross-Process Communication) é um framework leve e seguro fornecido
pelo macOS para comunicação entre processos distintos.^10^ No contexto
da captura de áudio do sistema, XPC é o canal através do qual a
aplicação principal (não privilegiada) se comunica com a helper tool
(privilegiada).^3^ A aplicação envia comandos para a helper tool (por
exemplo, iniciar ou parar a captura de áudio de um determinado PID) e a
helper tool pode retornar status ou dados de áudio.

O framework Foundation oferece a API de alto nível NSXPCConnection, que
simplifica a implementação de conexões XPC em Objective-C e Swift.^5^ A
comunicação é definida por um protocolo formal (uma interface @protocol
em Objective-C ou protocol em Swift) que ambas as partes concordam em
usar, especificando os métodos que podem ser chamados remotamente e os
tipos de dados que podem ser trocados.^11^ launchd desempenha um papel
fundamental ao ativar a helper tool sob demanda quando a aplicação
principal tenta estabelecer uma conexão XPC com o serviço Mach
registrado pela helper tool.^12^

**III. Configuração do Projeto no Xcode**

Uma configuração de projeto meticulosa é crucial para o sucesso da
implementação. Esta seção detalha os passos para criar os alvos,
estruturar os arquivos e configurar as definições de build e property
lists.

**A. Criação dos Alvos (Aplicação Principal e Helper Tool)**

O projeto consistirá em dois alvos principais ^13^:

1.  **Aplicação Principal (Cliente XPC):**

<!-- -->

1.  - Crie um novo projeto no Xcode utilizando o template \"App\" em
      > macOS.

    - Nomeie este alvo apropriadamente (ex: SystemAudioCaptureApp).

    - **Importante:** Para esta arquitetura específica, que depende de
      > SMJobBless para instalar uma helper tool que opera fora do
      > sandbox da aplicação, a aplicação principal geralmente não é
      > submetida à App Sandbox. Se o objetivo for distribuição fora da
      > Mac App Store, remova a capacidade \"App Sandbox\" das \"Signing
      > & Capabilities\" do alvo da aplicação principal. Se a Mac App
      > Store for um requisito, a arquitetura pode precisar de ajustes
      > ou pode não ser viável dependendo das permissões concedidas a
      > helpers de apps da Store. Para o escopo deste guia, assume-se a
      > ausência de sandbox para a aplicação principal para simplificar
      > a interação com SMJobBless.

<!-- -->

1.  **Helper Tool (Servidor XPC Privilegiado):**

<!-- -->

1.  - Adicione um novo alvo ao projeto existente.

    - Selecione o template \"Command Line Tool\" em macOS.

    - **Nome do Produto (Product Name):** Este nome é crítico. Deve ser
      > idêntico ao Label que será definido no launchd.plist da helper
      > tool e à chave usada no dicionário SMPrivilegedExecutables da
      > aplicação principal. Por convenção, utiliza-se notação DNS
      > reversa (ex: com.suaempresa.SystemAudioCaptureApp.Helper).^13^

    - Linguagem: Objective-C ou C para a helper tool, conforme exemplos
      > subsequentes.

**B. Estrutura de Arquivos e Fase de \"Copy Files\"**

A helper tool precisa ser embutida no bundle da aplicação principal em
um local específico para que SMJobBless possa encontrá-la.^6^

1.  **Dependência de Alvo:**

<!-- -->

1.  - Nas \"Build Phases\" do alvo da aplicação principal, adicione o
      > alvo da helper tool à seção \"Dependencies\". Isso garante que a
      > helper tool seja compilada antes da aplicação principal.

<!-- -->

1.  **Fase \"Copy Files\":**

<!-- -->

1.  - Ainda nas \"Build Phases\" da aplicação principal, adicione uma
      > nova fase \"Copy Files\".

    - Configure esta fase da seguinte maneira ^13^:

<!-- -->

1.  - - **Destination:** Wrapper

      - **Subpath:** Contents/Library/LaunchServices

      - Adicione o produto do alvo da helper tool (ex:
        > com.suaempresa.SystemAudioCaptureApp.Helper) à lista de
        > arquivos desta fase.

      - Marque a opção \"Code Sign On Copy\", se disponível e aplicável,
        > embora a assinatura principal ocorra na fase de build da
        > helper.

**C. Configurações de Build Essenciais**

Configurações específicas de build são necessárias para a helper tool,
principalmente para embutir seus arquivos Info.plist e launchd.plist
diretamente no binário executável.

- **Para o Alvo da Helper Tool:**

<!-- -->

- 1.  **Embutir Info.plist:**

<!-- -->

- 1.  - Nas \"Build Settings\" do alvo da helper tool, localize a
        > configuração Create Info.plist Section in Binary (ou
        > CREATE_INFOPLIST_SECTION_IN_BINARY). Defina-a como YES.^13^

      - Certifique-se de que a configuração Info.plist File (ou
        > INFOPLIST_FILE) aponta para o arquivo Info.plist correto da
        > sua helper tool (ex:
        > \$(SRCROOT)/NomeDaHelperTool/Helper-Info.plist).

<!-- -->

- 1.  **Embutir launchd.plist:**

<!-- -->

- 1.  - Nas \"Build Settings\" do alvo da helper tool, localize a
        > configuração Other Linker Flags (ou OTHER_LDFLAGS).

      - Adicione os seguintes flags, nesta ordem exata, substituindo
        > \$(SRCROOT)/NomeDaHelperTool/Helper-Launchd.plist pelo caminho
        > real para o seu arquivo launchd.plist ^5^:  
        > -Wl,-sectcreate,SEGMENT_NAME,SECTION_NAME,PATH_TO_PLIST  
        > Exemplo comumente usado:  
        > -Wl,-sectcreate,\_\_TEXT,\_\_launchd_plist,\$(SRCROOT)/NomeDaHelperTool/Helper-Launchd.plist  
        > (Nota: Alguns exemplos mais antigos podem usar -sectcreate
        > \_\_TEXT \_\_launchd_plist \$(PATH_TO_PLIST). A forma com -Wl,
        > é mais robusta para passar argumentos ao linker.)

**D. Configuração dos Arquivos Info.plist**

Ambos, a aplicação principal e a helper tool, requerem configurações
específicas em seus respectivos arquivos Info.plist.

1.  **Info.plist da Aplicação Principal:**

<!-- -->

1.  - **SMPrivilegedExecutables (Dicionário):** Esta chave é fundamental
      > para SMJobBless. Ela informa ao sistema sobre as helper tools
      > privilegiadas que esta aplicação tem permissão para instalar e
      > gerenciar.^5^

<!-- -->

1.  - - Cada entrada neste dicionário tem como chave o Label da helper
        > tool (ex: com.suaempresa.SystemAudioCaptureApp.Helper).

      - O valor associado a cada chave é uma string que representa o
        > requisito de assinatura de código da helper tool. Este
        > requisito garante que apenas uma helper tool com a assinatura
        > correta seja abençoada.

      - **Exemplo de XML:**  
        > XML  
        > \<key\>SMPrivilegedExecutables\</key\>  
        > \<dict\>  
        > \<key\>com.suaempresa.SystemAudioCaptureApp.Helper\</key\>  
        > \<string\>identifier
        > \"com.suaempresa.SystemAudioCaptureApp.Helper\" and anchor
        > apple generic and certificate
        > 1\[field.1.2.840.113635.100.6.2.6\] /\* exists \*/ and
        > certificate leaf\[field.1.2.840.113635.100.6.1.13\] /\* exists
        > \*/ and certificate leaf\[subject.OU\] =
        > SEU_TEAM_ID\</string\>  
        > \</dict\>  
        > Substitua \"com.suaempresa.SystemAudioCaptureApp.Helper\" pelo
        > identificador da sua helper tool e SEU_TEAM_ID pelo seu Team
        > ID de desenvolvedor Apple. A string de requisito pode ser
        > complexa; ferramentas como SMJobBlessUtil.py (discutida
        > posteriormente) podem ajudar a gerá-la.^15^ Alternativamente,
        > uma string mais simples como identifier
        > \"BUNDLE_ID_DA_HELPER\" and certificate leaf\[subject.CN\] =
        > \"SEU_NOME_DE_CERTIFICADO_COMPLETO\" pode funcionar, mas a
        > forma com anchor apple generic e Team ID é mais robusta.^8^

<!-- -->

1.  - **NSAudioCaptureUsageDescription (String):** Uma descrição do
      > motivo pelo qual sua aplicação precisa acessar a captura de
      > áudio. Isso é exibido ao usuário no diálogo de permissão do
      > sistema.^1^

<!-- -->

1.  - - **Exemplo de XML:**  
        > XML  
        > \<key\>NSAudioCaptureUsageDescription\</key\>  
        > \<string\>Esta aplicação precisa de acesso para capturar o
        > áudio do sistema para \[descreva a
        > funcionalidade\].\</string\>  

<!-- -->

1.  **Info.plist da Helper Tool (embutido no binário):**

<!-- -->

1.  - **SMAuthorizedClients (Array de Strings):** Esta chave especifica
      > quais aplicações cliente estão autorizadas a se conectar e usar
      > esta helper tool.^6^

<!-- -->

1.  - - Cada string no array é um requisito de assinatura de código para
        > uma aplicação cliente autorizada.

      - **Exemplo de XML:**  
        > XML  
        > \<key\>SMAuthorizedClients\</key\>  
        > \<array\>  
        > \<string\>identifier \"com.suaempresa.SystemAudioCaptureApp\"
        > and anchor apple generic and certificate
        > 1\[field.1.2.840.113635.100.6.2.6\] /\* exists \*/ and
        > certificate leaf\[field.1.2.840.113635.100.6.1.13\] /\* exists
        > \*/ and certificate leaf\[subject.OU\] =
        > SEU_TEAM_ID\</string\>  
        > \</array\>  
        > Substitua \"com.suaempresa.SystemAudioCaptureApp\" pelo
        > identificador da sua aplicação principal e SEU_TEAM_ID pelo
        > seu Team ID.

<!-- -->

1.  - **CFBundleIdentifier (String):** O identificador de bundle da
      > helper tool (ex: com.suaempresa.SystemAudioCaptureApp.Helper).

    - **CFBundleInfoDictionaryVersion (String):** Geralmente 6.0.

<!-- -->

1.  **launchd.plist da Helper Tool (embutido no binário):**

<!-- -->

1.  - **Label (String):** O identificador único para o job do launchd.
      > Este **deve** corresponder ao nome do arquivo executável da
      > helper tool e à chave usada em SMPrivilegedExecutables na
      > Info.plist da aplicação principal.^5^ (ex:
      > com.suaempresa.SystemAudioCaptureApp.Helper).

    - **MachServices (Dicionário):** Registra o serviço Mach que a
      > helper tool fornecerá para comunicação XPC.^12^

<!-- -->

1.  - - A chave dentro deste dicionário é o mesmo Label do job (ex:
        > com.suaempresa.SystemAudioCaptureApp.Helper).

      - O valor é um Booleano true.

<!-- -->

1.  - **Exemplo de XML (Helper-Launchd.plist):**  
      > XML  
      > \<?xml version=\"1.0\" encoding=\"UTF-8\"?\>  
      > \<!DOCTYPE **plist** **PUBLIC** \"-//Apple//DTD PLIST 1.0//EN\"
      > \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\"\>  
      > \<plist version=\"1.0\"\>  
      > \<dict\>  
      > \<key\>Label\</key\>  
      > \<string\>com.suaempresa.SystemAudioCaptureApp.Helper\</string\>  
      > \<key\>MachServices\</key\>  
      > \<dict\>  
      > \<key\>com.suaempresa.SystemAudioCaptureApp.Helper\</key\>  
      > \<true/\>  
      > \</dict\>  
      > \</dict\>  
      > \</plist\>  
      > Para uma helper tool ativada por XPC, RunAtLoad geralmente não é
      > necessário, pois launchd iniciará a helper quando uma conexão
      > XPC for tentada no serviço Mach registrado.^12^

**E. Code Signing e Entitlements**

A assinatura de código e os entitlements corretos são vitais para a
segurança e funcionalidade.

1.  **Assinatura de Código:**

<!-- -->

1.  - Tanto a aplicação principal quanto a helper tool **devem** ser
      > assinadas com um certificado de Developer ID emitido pela
      > Apple.^5^ Isso é um requisito fundamental para SMJobBless e para
      > a validação de segurança do XPC. Configure isso nas \"Signing &
      > Capabilities\" de cada alvo.

<!-- -->

1.  **Entitlements:**

<!-- -->

1.  - **Aplicação Principal:**

<!-- -->

1.  - - com.apple.security.system-audio-capture (Booleano: YES): Embora,
        > como discutido, este entitlement por si só não permita que a
        > aplicação principal chame AudioHardwareCreateProcessTap
        > diretamente para processos arbitrários, é uma boa prática
        > incluí-lo para declarar a intenção da aplicação.^3^ Pode ser
        > relevante para futuras mudanças no sistema ou para outras APIs
        > de captura. Crie um arquivo .entitlements para a aplicação
        > principal (ex: App.entitlements) e adicione:  
        > XML  
        > \<?xml version=\"1.0\" encoding=\"UTF-8\"?\>  
        > \<!DOCTYPE **plist** **PUBLIC** \"-//Apple//DTD PLIST
        > 1.0//EN\"
        > \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\"\>  
        > \<plist version=\"1.0\"\>  
        > \<dict\>  
        > \<key\>com.apple.security.system-audio-capture\</key\>  
        > \<true/\>  
        > \</dict\>  
        > \</plist\>  
        > Associe este arquivo nas \"Build Settings\" em Code Signing
        > Entitlements.

<!-- -->

1.  - **Helper Tool:**

<!-- -->

1.  - - com.apple.security.system-audio-capture (Booleano: YES): Este
        > entitlement é crucial para a helper tool, pois é ela quem fará
        > a chamada privilegiada para AudioHardwareCreateProcessTap.^3^
        > Crie um arquivo .entitlements para a helper tool (ex:
        > Helper.entitlements) e adicione:  
        > XML  
        > \<?xml version=\"1.0\" encoding=\"UTF-8\"?\>  
        > \<!DOCTYPE **plist** **PUBLIC** \"-//Apple//DTD PLIST
        > 1.0//EN\"
        > \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\"\>  
        > \<plist version=\"1.0\"\>  
        > \<dict\>  
        > \<key\>com.apple.security.system-audio-capture\</key\>  
        > \<true/\>  
        > \</dict\>  
        > \</plist\>  
        > Associe este arquivo nas \"Build Settings\" da helper tool em
        > Code Signing Entitlements. A helper tool, rodando como root,
        > opera com menos restrições de sandbox, mas entitlements
        > específicos podem ser verificados por frameworks individuais
        > como o Core Audio.

**IV. Instalação da Helper Tool com SMJobBless**

A aplicação principal é responsável por solicitar ao sistema a
instalação (ou \"bênção\") da helper tool. Este processo envolve obter
autorização do usuário e chamar a função SMJobBless.

**A. Obtendo AuthorizationRef**

Antes de chamar SMJobBless, a aplicação precisa obter uma referência de
autorização (AuthorizationRef) que contenha o direito
kSMRightBlessPrivilegedHelper. Este direito permite que a aplicação
instale uma helper tool no domínio do sistema
(kSMDomainSystemLaunchd).^6^

O processo geralmente envolve:

1.  Chamar AuthorizationCreate(nil, nil,, &authorization) para criar uma
    > instância de autorização vazia.^18^

2.  Definir uma estrutura AuthorizationItem especificando o nome do
    > direito kSMRightBlessPrivilegedHelper.

3.  Criar uma estrutura AuthorizationRights contendo este item.

4.  Chamar AuthorizationCopyRights(authorization, &rights, nil,
    > kAuthorizationFlagDefaults \| kAuthorizationFlagInteractionAllowed
    > \| kAuthorizationFlagPreAuthorize \|
    > kAuthorizationFlagExtendRights, nil) para solicitar o direito. A
    > flag kAuthorizationFlagInteractionAllowed fará com que o sistema
    > apresente um diálogo de autenticação ao usuário (solicitando nome
    > e senha de administrador) se o direito ainda não tiver sido
    > concedido ou pré-autorizado.^19^

**B. Chamando SMJobBless**

Com uma AuthorizationRef válida contendo o direito necessário, a
aplicação pode chamar SMJobBless.

A função SMJobBless tem a seguinte assinatura (Objective-C) 6:

Boolean SMJobBless(CFStringRef domain, CFStringRef executableLabel,
AuthorizationRef auth, CFErrorRef \*outError);

- domain: Deve ser kSMDomainSystemLaunchd para helper tools
  > privilegiadas.^6^

- executableLabel: O Label da helper tool, conforme definido em seu
  > launchd.plist e na chave SMPrivilegedExecutables da aplicação
  > principal.^6^

- auth: A AuthorizationRef obtida no passo anterior.

- outError: Um ponteiro para CFErrorRef que será preenchido com
  > informações de erro em caso de falha.^18^

Se SMJobBless retornar true, a helper tool foi instalada e registrada
com launchd com sucesso, ou já estava instalada. Se retornar false,
outError conterá detalhes sobre a falha.^6^ É crucial verificar este
erro para diagnóstico.

**C. Exemplo de Código Swift (Aplicação Principal)**

O código a seguir demonstra como implementar a lógica de instalação da
helper tool em Swift:

Swift

import Foundation  
import ServiceManagement  
import Security  
  
class HelperManager {  
  
static let shared = HelperManager()  
private let helperLabel =
\"com.suaempresa.SystemAudioCaptureApp.Helper\" // Substitua pelo seu
label  
  
private init() {}  
  
func installHelperIfNeeded(completion: @escaping (Result\<Void, Error\>)
-\> Void) {  
// Verificar se a helper tool já está abençoada/instalada  
// SMJobCopyDictionary pode ser usado para verificar, mas SMJobBless em
si é idempotente.  
// Se já estiver instalada, SMJobBless retorna true sem prompt. \[6\]  
  
var authRef: AuthorizationRef?  
var authStatus = AuthorizationCreate(nil, nil,, &authRef)  
  
guard authStatus == errAuthorizationSuccess else {  
let error = NSError(domain: NSOSStatusErrorDomain, code:
Int(authStatus), userInfo:)  
completion(.failure(error))  
return  
}  
  
// Liberar authRef quando não for mais necessário  
defer {  
if authRef!= nil {  
AuthorizationFree(authRef!,)  
}  
}  
  
var authItem = AuthorizationItem(name:
kSMRightBlessPrivilegedHelper.bytes, valueLength: 0, value: nil, flags:
0)  
var authRights = AuthorizationRights(count: 1, items: &authItem)  
  
let flags: AuthorizationFlags =  
  
authStatus = AuthorizationCopyRights(authRef!, &authRights, nil, flags,
nil)  
  
if authStatus == errAuthorizationInteractionNotAllowed {  
// O usuário pode ter clicado em \"Cancelar\" no diálogo de senha, ou
outra política impediu a interação.  
// O sistema geralmente lida com o prompt. Se este erro ocorrer, pode
ser que o prompt não foi mostrado  
// ou foi cancelado de uma forma que não retorna
errAuthorizationCanceled diretamente.  
// É importante verificar o CFError de SMJobBless também.  
print(\"AuthorizationCopyRights retornou
errAuthorizationInteractionNotAllowed. O usuário pode ter cancelado o
prompt ou a interação não foi permitida.\")  
}  
  
guard authStatus == errAuthorizationSuccess else {  
let error = NSError(domain: NSOSStatusErrorDomain, code:
Int(authStatus), userInfo:)  
completion(.failure(error))  
return  
}  
  
// Chamar SMJobBless  
var cfError: Unmanaged\<CFError\>?  
let blessStatus = SMJobBless(kSMDomainSystemLaunchd, helperLabel as
CFString, authRef, &cfError)  
  
if blessStatus {  
print(\"Helper tool abençoada com sucesso ou já estava abençoada.\")  
completion(.success(()))  
} else {  
let error = cfError?.takeRetainedValue() as Error??? NSError(domain:
\"com.suaempresa.SMJobBlessError\", code: -1, userInfo:)  
  
// Verificar se o erro é de cancelamento pelo usuário  
if let nsError = error as NSError?,  
nsError.domain == kCFErrorDomainCocoa as String && nsError.code ==
NSUserCancelledError {  
print(\"Instalação da Helper Tool cancelada pelo usuário.\")  
} else if let nsError = error as NSError?,  
nsError.domain == kCFErrorDomainOSStatus as String && nsError.code ==
errAuthorizationCanceled {  
print(\"Autorização para Helper Tool cancelada pelo usuário
(OSStatus).\")  
} else {  
print(\"SMJobBless falhou: \\error.localizedDescription)\")  
}  
completion(.failure(error))  
}  
}  
}  

Ao chamar AuthorizationCopyRights com
kAuthorizationFlagInteractionAllowed, o sistema operacional gerencia a
apresentação do diálogo de autenticação ao usuário, solicitando
credenciais de administrador. Este diálogo só aparece na primeira vez
que a aplicação tenta abençoar uma helper tool específica que ainda não
foi autorizada. Se a helper tool já estiver instalada e \"abençoada\"
pelo sistema, chamadas subsequentes a SMJobBless com uma
AuthorizationRef válida (mesmo que recém-criada e vazia, pois o direito
já foi concedido ao sistema para aquele helper) geralmente retornam true
sem reapresentar o diálogo ao usuário.^6^ Este comportamento simplifica
a lógica da aplicação, que não precisa rastrear explicitamente se o
prompt já foi exibido.

**V. Comunicação XPC entre Aplicação e Helper Tool**

Após a instalação bem-sucedida da helper tool, a aplicação principal
precisa de um meio para se comunicar com ela. XPC é a tecnologia
recomendada pela Apple para esta finalidade.

**A. Definindo o Protocolo XPC (Objective-C)**

Um protocolo formal define a interface de comunicação entre a aplicação
e a helper tool. Este protocolo deve ser compartilhado entre ambos os
processos. É comum defini-lo em um arquivo header Objective-C (.h) que
pode ser importado tanto pelo código Swift da aplicação principal quanto
pelo código Objective-C da helper tool.^11^

**AudioHelperProtocol.h:**

Objective-C

\#import \<Foundation/Foundation.h\>  
  
// Define blocos de resposta para operações assíncronas  
typedef void (\^AudioCaptureReplyBlock)(NSData\* \_Nullable audioData,
NSError\* \_Nullable error);  
typedef void (\^StatusReplyBlock)(BOOL success, NSError\* \_Nullable
error);  
  
NS_ASSUME_NONNULL_BEGIN  
  
@protocol AudioHelperProtocol  
@required  
// Método para obter a versão da helper tool (exemplo)  
- (void)getVersionWithReply:(void (\^\_Nonnull)(NSString\* \_Nonnull
version))reply;  
  
// Métodos para controlar a captura de áudio  
- (void)startAudioCaptureForPID:(pid_t)processID
withReply:(StatusReplyBlock \_Nonnull)reply;  
- (void)stopAudioCaptureWithReply:(StatusReplyBlock \_Nonnull)reply;  
  
// Outros métodos podem ser adicionados conforme necessário, por
exemplo, para  
// solicitar formatos de áudio específicos ou para obter dados de áudio
capturados  
// se não estiver usando uma abordagem de streaming contínuo.  
  
// Para captura contínua, a helper pode iniciar o envio de dados de
volta para a app,  
// ou a app pode fazer polling, ou a helper expõe um fluxo de dados
separado.  
// Para simplicidade, este exemplo usa métodos de requisição
explícitos.  
// Uma abordagem mais avançada pode envolver a helper enviando dados de
volta para a app  
// através de um objeto exportado pelo cliente (AppClientProtocol).  
// Exemplo:  
// - (void)registerAppClient:(id\<AppClientProtocol\>)client
withReply:(StatusReplyBlock \_Nonnull)reply;  
  
@optional  
// Métodos opcionais  
@end  
  
NS_ASSUME_NONNULL_END  

Este protocolo Objective-C é automaticamente \"ponteado\" (bridged) para
Swift, permitindo que seja utilizado de forma nativa no código Swift da
aplicação principal.

**B. Estabelecendo e Gerenciando a NSXPCConnection (Swift - Aplicação
Principal)**

A aplicação principal estabelece uma NSXPCConnection com a helper tool
usando o nome do serviço Mach registrado pela helper em seu
launchd.plist.

**Exemplo de classe XPCClient em Swift:**

Swift

import Foundation  
  
// Presume-se que AudioHelperProtocol.h está incluído no bridging header
do projeto Swift.  
  
class XPCClient {  
private var connection: NSXPCConnection?  
// O label deve ser o mesmo definido no launchd.plist da helper e em
SMPrivilegedExecutables  
private let helperLabel =
\"com.suaempresa.SystemAudioCaptureApp.Helper\"  
  
init() {  
// A conexão pode ser estabelecida sob demanda ou na inicialização.  
// setupConnection() // Opcionalmente, chame aqui ou quando
necessário.  
}  
  
private func setupConnection() {  
if connection!= nil {  
return // Já conectado ou em processo de conexão  
}  
  
// Para helper tools privilegiadas (rodando como root), use.privileged  
// Esta opção é crucial para helpers instaladas via SMJobBless. \[20\]  
let newConnection = NSXPCConnection(machServiceName: helperLabel,
options:.privileged)  
  
// Configurar a interface remota com o protocolo compartilhado  
newConnection.remoteObjectInterface = NSXPCInterface(with:
AudioHelperProtocol.self)  
  
// Se a aplicação principal precisar receber chamadas da helper tool
(bidirecional),  
// um protocolo AppClientProtocol seria definido e configurado aqui:  
// let appInterface = NSXPCInterface(with: AppClientProtocol.self)  
// newConnection.exportedInterface = appInterface  
// newConnection.exportedObject = self // \'self\' conformaria a
AppClientProtocol  
  
// Handlers para invalidação e interrupção da conexão  
newConnection.invalidationHandler = { \[weak self\] in  
print(\"XPC Connection Invalidated\")  
// A conexão foi permanentemente invalidada (ex: helper crashou,
desinstalada).  
// Limpar a referência e, possivelmente, tentar restabelecer ou
notificar o usuário.  
self?.connection = nil  
}  
newConnection.interruptionHandler = { \[weak self\] in  
print(\"XPC Connection Interrupted\")  
// A conexão foi temporariamente interrompida. Ela pode ser
restabelecida automaticamente.  
// Não é necessário limpar self?.connection aqui, pois o sistema pode
tentar reconectar.  
// Se a reconexão falhar, o invalidationHandler será chamado.  
}  
  
self.connection = newConnection  
self.connection?.resume() // Ativa a conexão. launchd iniciará a helper
se não estiver rodando. \[12\]  
print(\"XPC Connection setup initiated.\")  
}  
  
// Método para obter o proxy do objeto remoto da helper tool  
func getHelperService(errorHandler: @escaping (Error) -\> Void) -\>
AudioHelperProtocol? {  
if connection == nil {  
setupConnection() // Tenta estabelecer ou restabelecer se estiver nil  
}  
  
// remoteObjectProxyWithErrorHandler é assíncrono na obtenção do
proxy.  
// O handler de erro é chamado se ocorrer um erro ao obter o proxy ou
durante chamadas subsequentes.  
guard let remoteObject = connection?.remoteObjectProxyWithErrorHandler({
error in  
print(\"XPC remote object error: \\error.localizedDescription)\")  
errorHandler(error)  
}) as? AudioHelperProtocol else {  
let connectError = NSError(domain: \"com.suaempresa.XPCError\",  
code: -2,  
userInfo:)  
errorHandler(connectError)  
return nil  
}  
return remoteObject  
}  
  
func invalidateConnection() {  
connection?.invalidate()  
connection = nil  
}  
  
deinit {  
invalidateConnection()  
}  
}  

**C. Enviando Requisições de Captura de Áudio e Tratando Respostas/Dados
(Swift)**

Com a conexão XPC estabelecida, a aplicação principal pode chamar os
métodos definidos no AudioHelperProtocol.

**Exemplo de uso do XPCClient:**

Swift

// Em AppDelegate ou em uma classe gerenciadora relevante  
let xpcClient = XPCClient.shared // Supondo um singleton para
XPCClient  
  
func requestHelperVersion() {  
guard let helper = xpcClient.getHelperService(errorHandler: { error in  
print(\"Erro ao obter serviço da helper:
\\error.localizedDescription)\")  
// Tratar erro, ex: notificar usuário  
}) else {  
print(\"Não foi possível obter o serviço da helper.\")  
return  
}  
  
helper.getVersionWithReply { versionString in  
DispatchQueue.main.async { // Atualizar UI na thread principal  
print(\"Versão da Helper Tool: \\versionString)\")  
}  
}  
}  
  
func startAudioCapture(for pid: pid_t) {  
guard let helper = xpcClient.getHelperService(errorHandler: { error in  
print(\"Erro ao obter serviço da helper para iniciar captura:
\\error.localizedDescription)\")  
// Tratar erro  
}) else {  
print(\"Não foi possível obter o serviço da helper para iniciar
captura.\")  
return  
}  
  
helper.startAudioCaptureForPID(pid) { success, error in  
DispatchQueue.main.async {  
if success {  
print(\"Captura de áudio iniciada com sucesso para PID \\pid)\")  
} else {  
print(\"Falha ao iniciar captura de áudio:
\\error?.localizedDescription?? \"Erro desconhecido\")\")  
}  
}  
}  
}  
  
func stopAudioCapture() {  
guard let helper = xpcClient.getHelperService(errorHandler: { error in  
print(\"Erro ao obter serviço da helper para parar captura:
\\error.localizedDescription)\")  
// Tratar erro  
}) else {  
print(\"Não foi possível obter o serviço da helper para parar
captura.\")  
return  
}  
  
helper.stopAudioCapture { success, error in  
DispatchQueue.main.async {  
if success {  
print(\"Captura de áudio parada com sucesso.\")  
} else {  
print(\"Falha ao parar captura de áudio: \\error?.localizedDescription??
\"Erro desconhecido\")\")  
}  
}  
}  
}  

A comunicação XPC é inerentemente assíncrona. Todas as chamadas para a
helper tool que esperam uma resposta devem usar blocos de conclusão
(completion handlers/callbacks).^10^ A aplicação principal não deve
bloquear sua thread de interface do usuário (UI) aguardando uma resposta
da helper tool. A arquitetura XPC, com seus reply blocks, facilita este
padrão assíncrono, garantindo que a aplicação permaneça responsiva. As
atualizações da UI resultantes de respostas da helper devem ser
despachadas para a fila principal (DispatchQueue.main).

**VI. Implementação da Helper Tool Privilegiada (Objective-C/C)**

A helper tool é o componente que executa as operações privilegiadas de
Core Audio. Ela escuta por conexões XPC da aplicação principal e atua
sobre os comandos recebidos.

**A. Configurando o NSXPCListener e Delegate**

O ponto de entrada da helper tool (geralmente main.m ou uma classe
dedicada inicializada a partir de main.m) configura um NSXPCListener
para aceitar conexões XPC.

**AudioCaptureService.h (Declaração da classe que implementa o protocolo
e o delegate):**

Objective-C

\#import \<Foundation/Foundation.h\>  
\#import \"AudioHelperProtocol.h\" // Protocolo compartilhado  
  
NS_ASSUME_NONNULL_BEGIN  
  
@interface AudioCaptureService : NSObject \<AudioHelperProtocol,
NSXPCListenerDelegate\>  
  
// Propriedades e métodos relacionados ao Core Audio irão aqui  
// Exemplo:  
// @property (nonatomic, assign) AudioObjectID tapID;  
// @property (nonatomic, assign) AudioObjectID aggregateDeviceID;  
// @property (nonatomic, assign) AudioDeviceIOProcID ioProcID;  
// @property (nonatomic, strong) dispatch_queue_t audioProcessingQueue;
// Para processamento fora da thread de áudio  
  
@end  
  
NS_ASSUME_NONNULL_END  

**AudioCaptureService.m (Implementação parcial, focando no XPC e
estrutura do Core Audio):**

Objective-C

\#import \"AudioCaptureService.h\"  
\#import \<CoreAudio/CoreAudio.h\>  
\#import \<AVFoundation/AVFoundation.h\> // Para AVAudioSession, menos
provável para tap de sistema, mas pode ser útil para outras coisas.  
\#import \<os/log.h\> // Para logging unificado  
  
// Defina um os_log para a helper tool  
static os_log_t helper_log() {  
static dispatch_once_t onceToken;  
static os_log_t log;  
dispatch_once(&onceToken, \^{  
log = os_log_create(\"com.suaempresa.SystemAudioCaptureApp.Helper\",
\"HelperTool\");  
});  
return log;  
}  
  
@implementation AudioCaptureService {  
// Estado interno da captura  
BOOL \_isCapturing;  
pid_t \_targetPID;  
AudioObjectID \_tapID;  
AudioObjectID \_aggregateDeviceID;  
AudioDeviceIOProcID \_ioProcID; // ID do nosso IOProc  
AudioBufferList \*\_capturedAudioBufferList; // Buffer para dados de
áudio  
dispatch_queue_t \_audioDataHandlerQueue; // Fila para processar e
enviar dados de áudio  
}  
  
- (instancetype)init {  
self = \[super init\];  
if (self) {  
\_tapID = kAudioObjectUnknown;  
\_aggregateDeviceID = kAudioObjectUnknown;  
\_ioProcID = NULL;  
\_isCapturing = NO;  
\_targetPID = 0;  
\_audioDataHandlerQueue =
dispatch_queue_create(\"com.suaempresa.AudioDataHandlerQueue\",
DISPATCH_QUEUE_SERIAL);  
os_log(helper_log(), \"AudioCaptureService inicializado.\");  
}  
return self;  
}  
  
// Método do delegate NSXPCListener  
- (BOOL)listener:(NSXPCListener \*)listener
shouldAcceptNewConnection:(NSXPCConnection \*)newConnection {  
os_log(helper_log(), \"Nova conexão XPC recebida de PID: %d\",
newConnection.processIdentifier);  
  
// ETAPA CRÍTICA DE SEGURANÇA: Validar o cliente que está se
conectando.  
// Esta validação impede que aplicações não autorizadas se conectem à
helper tool.  
// A validação deve ser feita usando o audit token da conexão e
comparando  
// a assinatura do cliente com os requisitos definidos em
SMAuthorizedClients.  
// \[21, 22\]  
  
// Exemplo conceitual de validação (a implementação real é mais
complexa):  
// SecCodeRef clientCode = NULL;  
// SecCodeCopyGuestWithAttributes(NULL, (\_\_bridge
CFDictionaryRef)@{(\_\_bridge NSString \*)kSecGuestAttributeAudit:
newConnection.auditToken}, kSecCSDefaultFlags, &clientCode);  
// if (clientCode) {  
// // Obter os requisitos de SMAuthorizedClients do Info.plist
embutido  
// // CFStringRef requirementString =\... (lido do Info.plist)  
// // SecRequirementRef clientRequirement = NULL;  
// // SecRequirementCreateWithString(requirementString,
kSecCSDefaultFlags, &clientRequirement);  
// // OSStatus validationStatus = SecCodeCheckValidity(clientCode,
kSecCSDefaultFlags, clientRequirement);  
// // if (validationStatus!= errSecSuccess) {  
// // os_log_error(helper_log(), \"Validação do cliente XPC falhou:
%d\", validationStatus);  
// // CFRelease(clientCode);  
// // CFRelease(clientRequirement); // Se criado  
// // return NO; // Rejeitar conexão  
// // }  
// // CFRelease(clientCode);  
// // CFRelease(clientRequirement); // Se criado  
// } else {  
// os_log_error(helper_log(), \"Falha ao obter código do cliente XPC
para validação.\");  
// return NO; // Rejeitar conexão  
// }  
// os_log(helper_log(), \"Cliente XPC validado com sucesso.\");  
  
  
newConnection.exportedInterface =;  
newConnection.exportedObject = self; // \'self\' implementa
AudioHelperProtocol  
  
// Se a helper precisar chamar métodos na aplicação cliente
(bidirecional):  
// newConnection.remoteObjectInterface =;  
// id\<AppClientProtocol\> appClientProxy =
newConnection.remoteObjectProxy;  
// Armazenar appClientProxy se necessário para callbacks futuros.  
  
\[newConnection resume\];  
os_log(helper_log(), \"Conexão XPC aceita e resumida.\");  
return YES; // Aceitar a conexão  
}  
  
// Implementação dos métodos do AudioHelperProtocol  
  
- (void)getVersionWithReply:(void (\^)(NSString \* \_Nonnull))reply {  
os_log(helper_log(), \"Método getVersionWithReply chamado.\");  
reply(@\"1.0.1-Helper\"); // Versão de exemplo  
}  
  
// Implementação de startAudioCaptureForPID e stopAudioCaptureWithReply
(detalhada na próxima seção)  
//\... (código Core Audio aqui)\...  
  
@end  
  
  
// main.m (Ponto de entrada da Helper Tool)  
\#import \<Foundation/Foundation.h\>  
\#import \"AudioCaptureService.h\" // Importa a classe que implementa o
delegate e o protocolo  
\#import \<os/log.h\>  
  
// Defina um os_log para o main da helper tool  
static os_log_t main_helper_log() {  
static dispatch_once_t onceToken;  
static os_log_t log;  
dispatch_once(&onceToken, \^{  
log = os_log_create(\"com.suaempresa.SystemAudioCaptureApp.Helper\",
\"Main\");  
});  
return log;  
}  
  
int main(int argc, const char \* argv) {  
@autoreleasepool {  
os_log(main_helper_log(), \"Helper Tool iniciando\...\");  
  
AudioCaptureService \*serviceDelegate = init\];  
  
// Para um serviço XPC lançado pelo launchd (como é o caso com
SMJobBless),  
// use.  
NSXPCListener \*listener =;  
listener.delegate = serviceDelegate;  
  
\[listener resume\]; // Começa a aceitar conexões XPC  
os_log(main_helper_log(), \"NSXPCListener configurado e resumido.
Aguardando conexões.\");  
  
// Manter a helper tool viva para servir requisições.  
// Isto é essencial para um serviço XPC gerenciado pelo launchd.  
// O run loop impedirá que a helper tool saia imediatamente.  
run\];  
  
// Este ponto normalmente não é alcançado se o run loop estiver ativo.  
os_log(main_helper_log(), \"Run loop da Helper Tool terminou
(inesperado).\");  
}  
return 0;  
}  

A validação do cliente em listener:shouldAcceptNewConnection: é um ponto
de segurança crítico.^21^ A helper tool deve verificar rigorosamente a
assinatura de código do cliente que está tentando se conectar,
comparando-a com os requisitos definidos na chave SMAuthorizedClients de
seu próprio Info.plist. O uso de audit_token da conexão é a forma mais
segura de realizar essa validação, em vez de depender do PID do
processo, que pode ser reutilizado.^22^

**B. Implementando o HelperProtocol**

Os métodos definidos em AudioHelperProtocol.h são implementados dentro
da classe AudioCaptureService. Estes métodos conterão a lógica para
interagir com o Core Audio.

**C. Core Audio TAP: Implementação de AudioHardwareCreateProcessTap**

Esta é a parte central da helper tool, onde a captura de áudio é
configurada.

1.  Criando a CATapDescription:  
    > Um objeto CATapDescription é configurado para definir as
    > características do tap.1

<!-- -->

1.  - name: Um CFStringRef para o nome do tap (ex:
      > (CFStringRef)@\"MySystemAudioTap\").

    - processes: Um NSArray de NSNumber contendo os PIDs dos processos a
      > serem \"tapeados\". Se o objetivo é capturar \"áudio do
      > sistema\" de forma mais ampla (ex: a saída principal do sistema,
      > incluindo múltiplos aplicativos e sons do sistema), a abordagem
      > pode variar. AudioHardwareCreateProcessTap é explicitamente para
      > processos. Se um processID de 0 ou um array vazio for passado
      > para processes, o comportamento exato (se captura todo o áudio
      > do dispositivo de saída padrão ou falha) precisa ser verificado
      > experimentalmente, pois a documentação do ^1^ foca em PIDs
      > específicos. Para este guia, se processID for 0, tentaremos com
      > um array vazio, assumindo que pode capturar a mixagem do
      > dispositivo de saída padrão.

    - isPrivate: Booleano. NO para que o tap seja potencialmente visível
      > por outras ferramentas de áudio (para depuração), ou YES se
      > apenas esta helper for utilizá-lo.

    - muteBehavior: Define o que acontece com o áudio original do
      > processo tapeado. Opções incluem kCATapMuteBehaviorMuted (áudio
      > vai apenas para o tap), kCATapMuteBehaviorUnmuted (áudio vai
      > para o tap e para a saída normal),
      > kCATapMuteBehaviorLetPassThrough (áudio vai para a saída normal,
      > tap recebe uma cópia).^1^

    - isMixdown e isMono: Configuram o formato do áudio capturado (ex:
      > mixar para estéreo).^1^

<!-- -->

1.  **Criando o Tap e (Opcionalmente, mas Recomendado) um Dispositivo
    > Agregado:**

<!-- -->

1.  - Chame AudioHardwareCreateProcessTap((\_\_bridge
      > CATapDescriptionRef)tapDescription, &\_tapID) para criar o tap e
      > obter seu AudioObjectID.^1^ Verifique o OSStatus retornado e se
      > \_tapID não é kAudioObjectUnknown.

    - Para tornar o áudio do tap acessível como uma entrada de áudio
      > padrão, crie um dispositivo agregado (Aggregate Device) usando
      > AudioHardwareCreateAggregateDevice.^1^ Isso requer a criação de
      > um CFDictionaryRef com chaves como kAudioAggregateDeviceNameKey
      > e kAudioAggregateDeviceUIDKey.

    - Adicione o tap ao dispositivo agregado. Primeiro, obtenha o UID do
      > tap usando AudioObjectGetPropertyData com o seletor
      > kAudioTapPropertyUID. Em seguida, adicione este UID à lista de
      > taps do dispositivo agregado usando AudioObjectSetPropertyData
      > com o seletor kAudioAggregateDevicePropertyTapList no
      > AudioObjectID do dispositivo agregado.^1^

<!-- -->

1.  Gerenciando AudioDeviceIOProcs/Callbacks (Visão Geral Conceitual):  
    > Um AudioDeviceIOProc é uma função de callback C que o Core Audio
    > invoca quando novos dados de áudio estão disponíveis a partir de
    > um dispositivo de áudio -- neste caso, o dispositivo agregado que
    > contém nosso tap.2

<!-- -->

1.  - **Configuração:**

<!-- -->

1.  - - Defina uma função C estática que corresponda à assinatura de
        > AudioDeviceIOProc.

      - Use AudioDeviceCreateIOProcID (ou
        > AudioDeviceCreateIOProcIDWithBlock para uma abordagem baseada
        > em blocos) para registrar sua função de callback com o
        > dispositivo agregado e obter um AudioDeviceIOProcID.

      - Configure o dispositivo agregado para usar este IOProc,
        > especificando quais streams serão ativos, usando
        > kAudioDevicePropertyIOProcStreamUsage.^23^

      - Inicie o IOProc chamando AudioDeviceStart(aggregateDeviceID,
        > ioProcID).

<!-- -->

1.  - **Dentro do IOProc:**

<!-- -->

1.  - - A função de callback recebe ponteiros para AudioBufferList, que
        > contêm os dados de áudio capturados.

      - **CRÍTICO:** O IOProc executa em uma thread de áudio de alta
        > prioridade e tempo real. Qualquer processamento complexo,
        > alocação de memória, chamadas de sistema bloqueantes
        > (incluindo a maioria das chamadas XPC), ou atualizações de UI
        > (não aplicável na helper) **devem ser evitadas** diretamente
        > dentro do IOProc.^2^ Tais operações podem causar glitches de
        > áudio, dropouts ou instabilidade no sistema.

      - A estratégia correta é copiar rapidamente os dados de áudio dos
        > AudioBufferLists para um buffer interno (ring buffer ou
        > similar) e sinalizar outra thread (de menor prioridade) para
        > processar esses dados e enviá-los via XPC.

<!-- -->

1.  - **Parada:** Chame AudioDeviceStop(aggregateDeviceID, ioProcID) e
      > depois AudioDeviceDestroyIOProcID(aggregateDeviceID, ioProcID)
      > para limpar.

A complexidade do Core Audio, especialmente em suas restrições de tempo
real, é um desafio notório.^24^ A documentação pode ser esparsa ou
difícil de interpretar. A natureza de \"pull\" do Core Audio, onde o
callback precisa buscar os dados (embora para entrada, os dados sejam
\"empurrados\" para o callback), e as severas limitações sobre o que
pode ser feito em um callback de renderização ou IOProc, exigem um
design cuidadoso. Uma estratégia robusta de buffering e threading dentro
da helper tool não é opcional, mas um requisito para uma captura de
áudio confiável. A comunicação XPC, devido à sua sobrecarga inerente,
nunca deve ocorrer diretamente de dentro de um IOProc.

**Implementação Detalhada (continuação de AudioCaptureService.m):**

Objective-C

// Função de callback IOProc (deve ser uma função C estática ou um
bloco)  
static OSStatus MyAudioIOProc(AudioObjectID inDevice,  
const AudioTimeStamp\* inNow,  
const AudioBufferList\* inInputData,  
const AudioTimeStamp\* inInputTime,  
AudioBufferList\* outOutputData, // Não usado para captura de entrada  
const AudioTimeStamp\* inOutputTime, // Não usado  
void\* \_\_nullable inClientData) { // Ponteiro para nossa instância
AudioCaptureService  
  
AudioCaptureService \*self = (\_\_bridge AudioCaptureService
\*)inClientData;  
if (!self \|\|!self-\>\_isCapturing) {  
return noErr;  
}  
  
// Copiar dados de inInputData para um buffer interno de forma segura
para threads  
// e sinalizar a \_audioDataHandlerQueue para processamento e envio
XPC.  
// Exemplo MUITO simplificado de cópia (NÃO SEGURO PARA THREADS
DIRETAMENTE):  
for (UInt32 i = 0; i \< inInputData-\>mNumberBuffers; ++i) {  
if (self-\>\_capturedAudioBufferList && i \<
self-\>\_capturedAudioBufferList-\>mNumberBuffers) {  
// Garantir que o buffer de destino tem espaço suficiente  
if (self-\>\_capturedAudioBufferList-\>mBuffers\[i\].mDataByteSize \>=
inInputData-\>mBuffers\[i\].mDataByteSize) {  
memcpy(self-\>\_capturedAudioBufferList-\>mBuffers\[i\].mData,
inInputData-\>mBuffers\[i\].mData,
inInputData-\>mBuffers\[i\].mDataByteSize);  
self-\>\_capturedAudioBufferList-\>mBuffers\[i\].mDataByteSize =
inInputData-\>mBuffers\[i\].mDataByteSize; // Atualizar o tamanho  
// NSLog(@\"IOProc: Copiou %u bytes para o buffer %u\", (unsigned
int)inInputData-\>mBuffers\[i\].mDataByteSize, i);  
} else {  
os_log_error(helper_log(), \"IOProc: Buffer de destino pequeno
demais!\");  
}  
}  
}  
  
// Na prática, usar um ring buffer e despachar para outra fila:  
dispatch_async(self-\>\_audioDataHandlerQueue, \^{  
// Processar os dados de \_capturedAudioBufferList  
// Converter para NSData e enviar via XPC para a aplicação cliente  
// (se a app registrou um objeto cliente para receber dados)  
// Exemplo:  
// NSData \*audioChunk =.mData  
// length:self-\>\_capturedAudioBufferList-\>mBuffers.mDataByteSize\];  
//; // Método hipotético  
os_log_debug(helper_log(), \"IOProc: Dados recebidos, processamento
delegado.\");  
});  
  
return noErr;  
}  
  
  
- (void)startAudioCaptureForPID:(pid_t)processID
withReply:(StatusReplyBlock \_Nonnull)reply {  
os_log(helper_log(), \"Helper: Recebida requisição para iniciar captura
de áudio para PID: %d\", processID);  
if (\_isCapturing) {  
os_log_error(helper_log(), \"Helper: Captura já em progresso.\");  
NSError \*error =;  
reply(NO, error);  
return;  
}  
  
\_targetPID = processID;  
  
// \-\-- Criação do Core Audio TAP \-\--  
CATapDescription \*tapDescription = init\];  
tapDescription.name = (CFStringRef)@\"MySystemAudioTap\";  
  
if (processID \> 0) {  
tapDescription.processes = @;  
os_log(helper_log(), \"Helper: Configurando tap para PID %d.\",
processID);  
} else {  
// Tentar capturar áudio do sistema (mix de saída padrão) passando um
array vazio.  
// O comportamento exato disso deve ser testado.  
tapDescription.processes = @;  
os_log(helper_log(), \"Helper: Configurando tap para áudio geral do
sistema (sem PID específico).\");  
}  
  
tapDescription.isPrivate = NO;  
tapDescription.muteBehavior = kCATapMuteBehaviorLetPassThrough; // Ou
kCATapMuteBehaviorUnmuted  
tapDescription.isMixdown = YES; // Mixar para estéreo  
// tapDescription.isMono = NO; // Se isMixdown=YES e isMono=NO, é
estéreo.  
  
OSStatus status = AudioHardwareCreateProcessTap((\_\_bridge
CATapDescriptionRef)tapDescription, &\_tapID);  
  
if (status!= noErr \|  
\| \_tapID == kAudioObjectUnknown) {  
os_log_error(helper_log(), \"Helper: AudioHardwareCreateProcessTap
falhou com status: %d\", status);  
NSError \*error =;  
reply(NO, error);  
return;  
}  
os_log(helper_log(), \"Helper: Audio tap criado com ID: %u\", (unsigned
int)\_tapID);  
  
// \-\-- Criação do Dispositivo Agregado e Adição do Tap \-\--  
CFStringRef aggregateDeviceName = CFSTR(\"MyTapAggregateDevice\");  
CFStringRef aggregateDeviceUID = (CFStringRef) UUIDString\]; // UID
único  
CFDictionaryRef aggDeviceDescKeys = { kAudioAggregateDeviceNameKey,
kAudioAggregateDeviceUIDKey };  
CFTypeRef aggDeviceDescValues = { aggregateDeviceName,
aggregateDeviceUID };  
CFDictionaryRef aggregateDeviceDescription =
CFDictionaryCreate(kCFAllocatorDefault,  
(const void \*\*)aggDeviceDescKeys,  
(const void \*\*)aggDeviceDescValues,  
sizeof(aggDeviceDescKeys) / sizeof(aggDeviceDescKeys),  
&kCFTypeDictionaryKeyCallBacks,  
&kCFTypeDictionaryValueCallBacks);  
  
status = AudioHardwareCreateAggregateDevice(aggregateDeviceDescription,
&\_aggregateDeviceID);  
CFRelease(aggregateDeviceDescription);  
  
if (status!= noErr \|  
\| \_aggregateDeviceID == kAudioObjectUnknown) {  
os_log_error(helper_log(), \"Helper: AudioHardwareCreateAggregateDevice
falhou: %d\", status);  
AudioHardwareDestroyProcessTap(\_tapID); // Limpar tap  
\_tapID = kAudioObjectUnknown;  
NSError \*error =;  
reply(NO, error);  
return;  
}  
os_log(helper_log(), \"Helper: Dispositivo agregado criado com ID: %u\",
(unsigned int)\_aggregateDeviceID);  
  
// Obter UID do Tap e adicionar à Lista de Taps do Dispositivo Agregado
\[1\]  
AudioObjectPropertyAddress tapUIDPropAddress = { kAudioTapPropertyUID,
kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMain };  
CFStringRef tapUID = NULL;  
UInt32 dataSize = sizeof(tapUID);  
status = AudioObjectGetPropertyData(\_tapID, &tapUIDPropAddress, 0,
NULL, &dataSize, &tapUID);  
  
if (status == noErr && tapUID!= NULL) {  
CFArrayRef tapUIDArray = CFArrayCreate(kCFAllocatorDefault, (const void
\*\*)&tapUID, 1, &kCFTypeArrayCallBacks);  
AudioObjectPropertyAddress aggTapListPropAddress = {
kAudioAggregateDevicePropertyTapList, kAudioObjectPropertyScopeGlobal,
kAudioObjectPropertyElementMain };  
  
status = AudioObjectSetPropertyData(\_aggregateDeviceID,
&aggTapListPropAddress, 0, NULL, sizeof(CFArrayRef), &tapUIDArray); //
Passar ponteiro para o CFArrayRef  
  
if (status!= noErr) {  
os_log_error(helper_log(), \"Helper: Falha ao definir lista de taps no
dispositivo agregado: %d\", status);  
} else {  
os_log(helper_log(), \"Helper: Tap adicionado com sucesso ao dispositivo
agregado.\");  
}  
CFRelease(tapUIDArray);  
CFRelease(tapUID);  
} else {  
os_log_error(helper_log(), \"Helper: Falha ao obter UID do tap: %d\",
status);  
// Continuar mesmo assim? Ou falhar? Por ora, apenas logar.  
}  
  
// \-\-- Configurar e Iniciar IOProc \-\--  
// Alocar \_capturedAudioBufferList aqui com base no formato esperado do
dispositivo agregado.  
// Isso é complexo e depende do formato de áudio. Exemplo
simplificado:  
// Supondo 2 canais, float 32bit, 1024 frames  
// \_capturedAudioBufferList = (AudioBufferList
\*)malloc(sizeof(AudioBufferList) + sizeof(AudioBuffer)); // Para 1
buffer  
// \_capturedAudioBufferList-\>mNumberBuffers = 1;  
// \_capturedAudioBufferList-\>mBuffers.mNumberChannels = 2;  
// \_capturedAudioBufferList-\>mBuffers.mDataByteSize = 1024 \* 2 \*
sizeof(float);  
// \_capturedAudioBufferList-\>mBuffers.mData =
malloc(\_capturedAudioBufferList-\>mBuffers.mDataByteSize);  
  
  
status = AudioDeviceCreateIOProcIDWithBlock(&\_ioProcID,
\_aggregateDeviceID, dispatch_get_main_queue(), \^(AudioObjectID
inDevice, const AudioTimeStamp \*inNow, const AudioBufferList
\*inInputData, const AudioTimeStamp \*inInputTime, AudioBufferList
\*outOutputData, const AudioTimeStamp \*inOutputTime) {  
MyAudioIOProc(inDevice, inNow, inInputData, inInputTime, outOutputData,
inOutputTime, (\_\_bridge void \* \_Nullable)(self));  
});  
  
if (status!= noErr) {  
os_log_error(helper_log(), \"Helper: AudioDeviceCreateIOProcIDWithBlock
falhou: %d\", status);  
// Limpar tap e dispositivo agregado  
if (\_aggregateDeviceID!= kAudioObjectUnknown)
AudioHardwareDestroyAggregateDevice(\_aggregateDeviceID);  
if (\_tapID!= kAudioObjectUnknown)
AudioHardwareDestroyProcessTap(\_tapID);  
\_aggregateDeviceID = kAudioObjectUnknown; \_tapID =
kAudioObjectUnknown;  
NSError \*error =;  
reply(NO, error);  
return;  
}  
os_log(helper_log(), \"Helper: IOProc criado com ID.\");  
  
status = AudioDeviceStart(\_aggregateDeviceID, \_ioProcID);  
if (status!= noErr) {  
os_log_error(helper_log(), \"Helper: AudioDeviceStart falhou: %d\",
status);  
// Limpar IOProcID, tap e dispositivo agregado  
AudioDeviceDestroyIOProcID(\_aggregateDeviceID, \_ioProcID); \_ioProcID
= NULL;  
if (\_aggregateDeviceID!= kAudioObjectUnknown)
AudioHardwareDestroyAggregateDevice(\_aggregateDeviceID);  
if (\_tapID!= kAudioObjectUnknown)
AudioHardwareDestroyProcessTap(\_tapID);  
\_aggregateDeviceID = kAudioObjectUnknown; \_tapID =
kAudioObjectUnknown;  
NSError \*error =;  
reply(NO, error);  
return;  
}  
os_log(helper_log(), \"Helper: IOProc iniciado no dispositivo agregado
%u.\", (unsigned int)\_aggregateDeviceID);  
  
\_isCapturing = YES;  
os_log(helper_log(), \"Helper: Captura de áudio iniciada para tap ID %u
no dispositivo agregado ID %u.\", (unsigned int)\_tapID, (unsigned
int)\_aggregateDeviceID);  
reply(YES, nil);  
}  
  
- (void)stopAudioCaptureWithReply:(StatusReplyBlock \_Nonnull)reply {  
os_log(helper_log(), \"Helper: Recebida requisição para parar captura de
áudio.\");  
if (!\_isCapturing) {  
os_log_error(helper_log(), \"Helper: Captura não está em
progresso.\");  
NSError \*error =;  
reply(NO, error);  
return;  
}  
  
// Parar IOProc  
if (\_aggregateDeviceID!= kAudioObjectUnknown && \_ioProcID!= NULL) {  
OSStatus status = AudioDeviceStop(\_aggregateDeviceID, \_ioProcID);  
if (status!= noErr) {  
os_log_error(helper_log(), \"Helper: Falha ao parar IOProc: %d\",
status);  
} else {  
os_log(helper_log(), \"Helper: IOProc parado.\");  
}  
AudioDeviceDestroyIOProcID(\_aggregateDeviceID, \_ioProcID);  
\_ioProcID = NULL;  
os_log(helper_log(), \"Helper: IOProc destruído.\");  
}  
  
// Destruir dispositivo agregado  
if (\_aggregateDeviceID!= kAudioObjectUnknown) {  
OSStatus status =
AudioHardwareDestroyAggregateDevice(\_aggregateDeviceID);  
if (status!= noErr) {  
os_log_error(helper_log(), \"Helper: Falha ao destruir dispositivo
agregado: %d\", status);  
} else {  
os_log(helper_log(), \"Helper: Dispositivo agregado destruído.\");  
}  
\_aggregateDeviceID = kAudioObjectUnknown;  
}  
  
// Destruir tap  
if (\_tapID!= kAudioObjectUnknown) {  
OSStatus status = AudioHardwareDestroyProcessTap(\_tapID);  
if (status!= noErr) {  
os_log_error(helper_log(), \"Helper: Falha ao destruir audio tap: %d\",
status);  
} else {  
os_log(helper_log(), \"Helper: Audio tap destruído.\");  
}  
\_tapID = kAudioObjectUnknown;  
}  
  
// Limpar buffer de áudio  
// if (\_capturedAudioBufferList) {  
// if (\_capturedAudioBufferList-\>mBuffers.mData) {  
// free(\_capturedAudioBufferList-\>mBuffers.mData);  
// }  
// free(\_capturedAudioBufferList);  
// \_capturedAudioBufferList = NULL;  
// }  
  
  
\_isCapturing = NO;  
\_targetPID = 0;  
os_log(helper_log(), \"Helper: Captura de áudio parada e recursos
liberados.\");  
reply(YES, nil);  
}  
  
@end  

**D. Retransmitindo Dados de Áudio para a Aplicação Principal via XPC**

Uma vez que os dados de áudio são capturados pelo IOProc e seguramente
copiados para um buffer em uma thread separada, eles precisam ser
enviados para a aplicação principal.

- **Mecanismo:**

<!-- -->

- 1.  Se a aplicação principal registrou um objeto cliente exportado com
      > a helper tool (por exemplo, um objeto que conforma a um
      > AppClientProtocol com um método como
      > -(void)receiveAudioData:(NSData \*)audioData;), a helper tool
      > pode chamar este método no proxy remoto do cliente para enviar
      > pacotes de NSData.

  2.  Alternativamente, a aplicação principal poderia ter um método no
      > AudioHelperProtocol como
      > -(void)requestNextAudioChunkWithReply:(AudioCaptureReplyBlock)reply;
      > que ela chama periodicamente. No entanto, esta abordagem de
      > polling é menos eficiente para fluxos contínuos de áudio em
      > comparação com a helper tool \"empurrando\" os dados para a
      > aplicação.

<!-- -->

- **Formato dos Dados:** NSData é adequado para XPC. É crucial que a
  > aplicação e a helper tool concordem sobre o formato de áudio (taxa
  > de amostragem, profundidade de bits, número de canais) que está
  > sendo transmitido. Pode ser necessário realizar conversão de taxa de
  > amostragem na helper tool se o formato natural do tap diferir do que
  > a aplicação espera ou pode processar eficientemente.^2^

**VII. Depurando o Ecossistema: Dicas e Truques**

Depurar um sistema que envolve múltiplos processos, privilégios elevados
e comunicação interprocessos pode ser complexo. As ferramentas e
técnicas a seguir são essenciais.

**A. Usando Console.app para Logs do launchd e da Helper**

A aplicação Console.app é indispensável. launchd registra suas
atividades, incluindo operações de SMJobBless e o ciclo de vida da
helper tool. Além disso, quaisquer NSLog (ou os_log como usado nos
exemplos acima) da helper tool aparecerão na Console.app, e não no
console do depurador do Xcode, pois a helper é um processo separado.^5^

- **Filtragem:** Use os recursos de filtro da Console.app para focar em
  > mensagens do seu subsistema (usando o bundle ID da helper ou da
  > app), ou termos como \"SMJobBless\", \"launchd\", ou o nome da sua
  > aplicação.

**B. Diagnosticando Falhas do SMJobBless**

Falhas em SMJobBless geralmente se devem a configurações incorretas.

- **Causas Comuns:**

<!-- -->

- 1.  **Problemas de Assinatura de Código:** Certificados incompatíveis,
      > strings de requisito incorretas em SMPrivilegedExecutables (app)
      > ou SMAuthorizedClients (helper). Helper ou app não assinados, ou
      > assinados com certificados diferentes quando os requisitos
      > especificam o mesmo TeamID.^13^

  2.  **Configuração Incorreta de Plist:** Label incorreto no
      > launchd.plist da helper, nome do executável da helper não
      > correspondendo ao Label, plists não embutidos corretamente no
      > binário da helper.^13^

  3.  **Localização da Helper:** Helper tool não está em
      > Contents/Library/LaunchServices dentro do bundle da aplicação
      > principal.^6^

  4.  **Permissões:** AuthorizationRef não obtido corretamente ou não
      > contém o direito kSMRightBlessPrivilegedHelper. O usuário pode
      > ter cancelado o prompt de senha.^18^

<!-- -->

- Tabela: Códigos de Erro Comuns do SMJobBless (de CFErrorRef e
  > SMErrors.h)  
  > Esta tabela ajuda a diagnosticar rapidamente problemas com
  > SMJobBless.13

|                                |                                              |                                                                                                                                                  |                                                                                                                                                                                                                                             |
|--------------------------------|----------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Código de Erro (Constante)** | **Valor Numérico (OSStatus) / Código Cocoa** | **Causa Provável**                                                                                                                               | **Passos de Depuração Sugeridos**                                                                                                                                                                                                           |
| kSMErrorInternalFailure        | 2                                            | Falha interna no framework ServiceManagement.                                                                                                    | Verificar logs do sistema no Console.app. Tentar novamente. Se persistir, pode ser um bug do sistema.                                                                                                                                       |
| kSMErrorInvalidSignature       | 3                                            | Assinatura de código da aplicação ou da helper tool inválida ou não atende aos requisitos.                                                       | Verificar se ambos os alvos (app e helper) estão assinados corretamente com Developer ID. Validar as strings de requisito em SMPrivilegedExecutables e SMAuthorizedClients. Usar SMJobBlessUtil.py check.                                   |
| kSMErrorAuthorizationFailure   | 4                                            | AuthorizationRef não contém o direito kSMRightBlessPrivilegedHelper.                                                                             | Garantir que AuthorizationCopyRights foi chamado corretamente para kSMRightBlessPrivilegedHelper.                                                                                                                                           |
| kSMErrorToolNotValid           | 5                                            | O caminho para a helper tool não existe, ou a helper tool no caminho especificado é inválida (e.g., não executável, arquitetura errada).         | Verificar se a helper tool está corretamente copiada para Contents/Library/LaunchServices no bundle da app. Garantir que a helper tool é um executável válido e compilado para a arquitetura correta.                                       |
| kSMErrorJobNotFound            | 6                                            | Um job com o Label especificado não foi encontrado (relevante para SMJobRemove ou SMJobCopyDictionary).                                          | Verificar se o Label está correto.                                                                                                                                                                                                          |
| kSMErrorServiceUnavailable     | 7                                            | O serviço launchd está indisponível.                                                                                                             | Problema raro, pode indicar um problema mais amplo no sistema. Reiniciar o macOS.                                                                                                                                                           |
| kSMErrorJobPlistNotFound       | 8                                            | O arquivo launchd.plist da helper tool não foi encontrado ou não está embutido corretamente.                                                     | Verificar as configurações do linker (-Wl,-sectcreate,\_\_TEXT,\_\_launchd_plist,\...) para embutir o launchd.plist na helper tool.                                                                                                         |
| kSMErrorJobMustBeEnabled       | 9                                            | O job está desabilitado (relevante para SMJobSubmit se usado).                                                                                   | Geralmente não aplicável para SMJobBless que lida com a habilitação.                                                                                                                                                                        |
| kSMErrorInvalidPlist           | 10                                           | O Info.plist ou launchd.plist da helper tool é inválido (e.g., XML malformado, chaves ausentes ou incorretas).                                   | Validar a sintaxe XML dos arquivos plist. Garantir que todas as chaves requeridas (Label e MachServices em launchd.plist, SMAuthorizedClients e CFBundleIdentifier em Info.plist) estão presentes e corretas. Usar SMJobBlessUtil.py check. |
| errAuthorizationCanceled       | -60006 (OSStatus)                            | Usuário cancelou o diálogo de senha para autorização.                                                                                            | Tratar este caso graciosamente na UI da aplicação, informando o usuário.                                                                                                                                                                    |
| NSUserCancelledError           | 4 (Cocoa Error Domain)                       | Usuário cancelou uma operação (pode ser retornado pelo CFError de SMJobBless se o cancelamento da autorização for mapeado para este erro Cocoa). | Similar ao errAuthorizationCanceled.                                                                                                                                                                                                        |

**C. Solução de Problemas de Conexão e Comunicação XPC**

- **Causas Comuns:**

<!-- -->

- 1.  **Incompatibilidade de Nome de Serviço Mach:** A aplicação
      > principal tenta se conectar a um nome de serviço diferente do
      > que está registrado pela helper em seu launchd.plist (chave
      > MachServices).

  2.  **Incompatibilidade de Protocolo:** NSXPCInterface não configurado
      > corretamente em um ou ambos os lados, ou métodos no protocolo
      > não implementados conforme esperado (assinaturas de método,
      > tipos de parâmetros/retorno).

  3.  **Falha na Validação do Cliente:** O método
      > listener:shouldAcceptNewConnection: da helper tool rejeita a
      > conexão devido a falha na verificação de assinatura/requisitos
      > do cliente.^21^

  4.  **Problemas de Serialização:** Tentativa de enviar objetos não
      > conformes com NSSecureCoding via XPC sem configuração adequada
      > (embora para NSData, isso geralmente funcione bem).

  5.  Helper tool travando ou não sendo executada (verificar logs da
      > helper na Console.app).

<!-- -->

- **Passos de Depuração:**

<!-- -->

- - Verificar os_log ou NSLog tanto na aplicação quanto na helper em
    > torno da configuração e chamadas XPC.

  - Verificar Console.app por erros relacionados a XPC de launchd ou do
    > sistema.

  - Definir breakpoints em listener:shouldAcceptNewConnection: e nas
    > implementações dos métodos XPC na helper.

  - Garantir que o run loop da helper tool está ativo e que ela não está
    > saindo prematuramente.

**D. Lidando com kAudioHardwareIllegalOperationError (what /
2003329396)**

Este erro é específico do Core Audio, frequentemente encontrado ao
chamar AudioHardwareCreateProcessTap.^3^

- **Causa Principal (Conforme Estabelecido):** Chamá-lo de um contexto
  > de processo não autorizado (ou seja, diretamente da aplicação
  > principal para processos arbitrários).^3^ A solução é chamá-lo de
  > dentro da helper tool privilegiada.

- **Outras Causas Potenciais (Dentro da Helper):**

<!-- -->

- - CATapDescription inválida (ex: PIDs malformados, seleção de stream
    > inválida).

  - O processo alvo não existe ou não está produzindo áudio.

  - Limitações de recursos do sistema (menos comum).

  - Ausência do entitlement com.apple.security.system-audio-capture na
    > própria helper tool.

**E. O Script SMJobBlessUtil.py**

A Apple historicamente forneceu um script Python, SMJobBlessUtil.py, em
seus exemplos de código (como o SMJobBless original ou o
EvenBetterAuthorizationSample) para ajudar a diagnosticar problemas de
configuração do SMJobBless, especialmente com requisitos de assinatura
de código e configurações de plist.^5^

- **Comandos:**

<!-- -->

- - check: Valida o bundle da aplicação e a configuração da helper.

  - setreq: Ajuda a gerar ou atualizar as strings de requisito de
    > assinatura de código para os arquivos Info.plist.

<!-- -->

- **Uso:** Executado via Terminal, apontando para o bundle da aplicação
  > construída e os arquivos Info.plist relevantes. Exemplo:
  > ./SMJobBlessUtil.py check /path/to/YourApp.app.

**VIII. Melhores Práticas de Segurança e Considerações**

A implementação de uma helper tool privilegiada exige atenção rigorosa à
segurança.

**A. Princípio do Menor Privilégio para a Helper Tool**

Mesmo que a helper tool seja executada como root, ela deve ser projetada
para realizar apenas o conjunto mínimo absoluto de operações necessárias
para sua tarefa (neste caso, captura de áudio e comunicação XPC
relacionada).^9^ Evite adicionar funcionalidades privilegiadas não
relacionadas. O código privilegiado deve ser estritamente isolado dentro
da helper. Como afirmado em guias de codificação segura da Apple, \"Na
prática, o princípio do menor privilégio significa que você deve evitar
rodar como root, ou --- se for absolutamente necessário rodar como root
para realizar alguma tarefa --- você deve rodar uma aplicação helper
separada para realizar a tarefa privilegiada.\".^28^

**B. Validando Conexões de Cliente XPC na Helper
(listener:shouldAcceptNewConnection:)**

Este é o ponto de controle de acesso mais crítico da helper tool. Ela
**deve** validar rigorosamente qualquer requisição de conexão XPC antes
de exportar sua interface e objeto.^21^

- **Passos de Validação:**

<!-- -->

- 1.  Obtenha o audit_token_t do cliente da conexão a partir de
      > newConnection.auditToken.

  2.  Use SecCodeCopyGuestWithAttributes com o audit_token para obter
      > uma SecCodeRef representando o código do cliente.

  3.  Use SecCodeCheckValidityWithErrors (ou SecCodeCheckValidity) para
      > verificar a assinatura do cliente em relação aos requisitos
      > definidos no array SMAuthorizedClients da helper tool (embutido
      > em seu Info.plist).

  4.  Verifique o identificador de bundle do cliente e, opcionalmente, a
      > versão mínima, se estes fizerem parte dos seus requisitos de
      > segurança.

  5.  **Não confie no PID para verificações de segurança**, pois os PIDs
      > podem ser reutilizados por outros processos após um cliente
      > legítimo sair.^22^

A utilização de audit_token para identificar o cliente XPC é fundamental
para a segurança. Tentar validar um cliente com base em seu
processIdentifier (PID) é inerentemente inseguro devido à possibilidade
de reutilização de PID. Um processo malicioso poderia, teoricamente,
obter rapidamente o PID de um cliente legítimo que acabou de se
desconectar e, assim, personificá-lo se a validação dependesse apenas do
PID. O audit_token, por outro lado, fornece uma referência mais estável
e segura para o processo de conexão, permitindo uma validação confiável
de sua assinatura de código contra os requisitos definidos em
SMAuthorizedClients.^22^ Esta abordagem garante que apenas clientes
autenticados e autorizados possam interagir com a helper tool
privilegiada.

**C. Manipulação Segura de Dados e Comandos via XPC**

- **Validação de Entrada:** A helper tool deve validar todos os
  > parâmetros recebidos da aplicação principal via XPC (ex: PIDs,
  > configurações) para prevenir comportamento inesperado ou exploração.

- **Sanitização de Saída:** Garanta que os dados enviados de volta para
  > a aplicação são o que se espera.

- **Propagação de Erros:** Propague erros da helper de volta para a
  > aplicação de forma segura e clara.

- **Objetos Simples:** Prefira tipos de property list (NSString,
  > NSNumber, NSData, NSArray, NSDictionary) ou NSData para comunicação
  > XPC. Se classes personalizadas forem usadas, garanta que elas
  > estejam em conformidade com NSSecureCoding para evitar
  > vulnerabilidades de serialização.^10^

**D. Desinstalação da Helper Tool**

É uma boa prática fornecer um mecanismo para que a aplicação principal
solicite a desinstalação da helper tool.

- **Mecanismo:** Isso normalmente envolve chamar a função SMJobRemove do
  > framework ServiceManagement. Assim como SMJobBless, SMJobRemove
  > requer uma AuthorizationRef com direitos apropriados (geralmente o
  > mesmo kSMRightBlessPrivilegedHelper ou um direito específico de
  > remoção, se definido).

- SMJobRemove cuidará da remoção do job do launchd (removendo o
  > launchd.plist de /Library/LaunchDaemons) e do executável da helper
  > de /Library/PrivilegedHelperTools.^29^ Scripts de desinstalação
  > manuais, como o mencionado em ^13^, geralmente usam launchctl
  > unload, launchctl remove e rm para esses arquivos. A API SMJobRemove
  > é a abordagem programática preferida. ^22^ também menciona
  > SMJobRemove ou launchctl para desinstalação.

**IX. Conclusão e Desenvolvimentos Futuros**

A implementação da captura de áudio do sistema no macOS 14 utilizando
Core Audio Taps através de uma helper tool privilegiada instalada com
SMJobBless e comunicando-se via XPC é uma tarefa complexa, porém robusta
e alinhada com as melhores práticas de segurança da Apple. Este guia
detalhou os passos necessários, desde a configuração do projeto até a
implementação e depuração, enfatizando os pontos críticos de segurança e
as nuances do Core Audio.

**Principais Aprendizados:**

- A necessidade de uma helper tool privilegiada para
  > AudioHardwareCreateProcessTap é ditada pelas políticas de segurança
  > do macOS.

- SMJobBless e XPC fornecem a infraestrutura segura para instalar e
  > comunicar com tal helper.

- A assinatura de código e a configuração correta dos Info.plist e
  > launchd.plist são cruciais.

- A validação rigorosa do cliente XPC na helper tool é imperativa.

- O manuseio de AudioDeviceIOProcs do Core Audio requer extremo cuidado
  > devido às suas restrições de tempo real.

**Limitações:**

- A complexidade inerente do Core Audio continua sendo uma barreira
  > significativa, com documentação muitas vezes considerada
  > inadequada.^24^

- Embora a arquitetura SMJobBless/XPC seja estável, futuras atualizações
  > do macOS podem introduzir mudanças que exijam adaptação. Empresas
  > como a Rogue Amoeba, com produtos como Audio Hijack, demonstram um
  > esforço contínuo para se adaptar às evoluções do macOS na captura de
  > áudio ^30^, mas o modelo fundamental de helper privilegiada
  > permanece válido.

**Ideias para Desenvolvimento Futuro:**

- Implementação de buffering de dados de áudio mais sofisticado (ex:
  > ring buffers) e estratégias de streaming otimizadas.

- Adição de suporte para selecionar dispositivos de áudio específicos
  > para \"tapear\", além de PIDs de processos.

- Criação de uma interface de usuário na aplicação principal para
  > gerenciar os processos \"tapeados\" e o status da captura.

- Para cenários que exigem a captura de \"todo o áudio do sistema\" de
  > uma forma que AudioHardwareCreateProcessTap possa ser muito
  > restritivo (por exemplo, se não for possível ou prático enumerar
  > todos os PIDs relevantes ou se o objetivo for capturar a mixagem de
  > saída final independentemente dos processos), a exploração de
  > alternativas como a criação de um driver de áudio virtual
  > (semelhante ao Loopback da Rogue Amoeba ^31^ ou BlackHole) pode ser
  > considerada. Tais drivers operam em um nível diferente e podem ter
  > requisitos de permissão distintos ^3^, mas estão fora do escopo
  > direto desta documentação focada em Core Audio Taps.

Este guia técnico fornece uma base sólida para desenvolvedores que
buscam implementar a captura de áudio do sistema no macOS de maneira
eficaz e segura. A atenção aos detalhes, especialmente em relação à
segurança e ao manuseio das APIs de baixo nível do Core Audio, será
fundamental para o sucesso.

Referências citadas

1.  Capturing system audio with Core Audio taps \| Apple Developer \...,
    > acessado em junho 12, 2025,
    > [*https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps*](https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps)

2.  From Core Audio to LLMs: Native macOS Audio Capture for AI-Powered
    > Tools - Chisto, acessado em junho 12, 2025,
    > [*https://chisto.com/from-core-audio-to-llms-native-macos-audio-capture-for-ai-powered-tools/*](https://chisto.com/from-core-audio-to-llms-native-macos-audio-capture-for-ai-powered-tools/)

3.  Anyone have any luck capturing system audio from individual apps
    > using Core Audio? : r/macapps - Reddit, acessado em junho 12,
    > 2025,
    > [*https://www.reddit.com/r/macapps/comments/1kgnwor/anyone_have_any_luck_capturing_system_audio_from/*](https://www.reddit.com/r/macapps/comments/1kgnwor/anyone_have_any_luck_capturing_system_audio_from/)

4.  Anyone have success with capturing system audio and capturing it
    > from individual apps using Core Audio? : r/macosprogramming -
    > Reddit, acessado em junho 12, 2025,
    > [*https://www.reddit.com/r/macosprogramming/comments/1kgnvyp/anyone_have_success_with_capturing_system_audio/*](https://www.reddit.com/r/macosprogramming/comments/1kgnvyp/anyone_have_success_with_capturing_system_audio/)

5.  brenwell/SMJobBless-Demo: Apple\'s sample application updated for
    > Xcode 5 - GitHub, acessado em junho 12, 2025,
    > [*https://github.com/brenwell/SMJobBless-Demo*](https://github.com/brenwell/SMJobBless-Demo)

6.  SMJobBless \| Apple Developer Documentation, acessado em junho 12,
    > 2025,
    > [*https://developer.apple.com/documentation/servicemanagement/smjobbless(\_:\_:\_:\_:)?language=objc*](https://developer.apple.com/documentation/servicemanagement/smjobbless(_:_:_:_:)?language=objc)

7.  Escalating privileges on Mac OS X securely, and without using
    > deprecated methods, acessado em junho 12, 2025,
    > [*https://www.stevestreeting.com/2011/11/25/escalating-privileges-on-mac-os-x-securely-and-without-using-deprecated-methods/*](https://www.stevestreeting.com/2011/11/25/escalating-privileges-on-mac-os-x-securely-and-without-using-deprecated-methods/)

8.  fruitsamples/SMJobBless - GitHub, acessado em junho 12, 2025,
    > [*https://github.com/fruitsamples/SMJobBless*](https://github.com/fruitsamples/SMJobBless)

9.  What is CCC\'s Privileged Helper Tool? - Bombich Software Knowledge
    > Base, acessado em junho 12, 2025,
    > [*https://support.bombich.com/hc/en-us/articles/20686388957719-What-is-CCC-s-Privileged-Helper-Tool*](https://support.bombich.com/hc/en-us/articles/20686388957719-What-is-CCC-s-Privileged-Helper-Tool)

10. XPC \| Apple Developer Documentation, acessado em junho 12, 2025,
    > [*https://developer.apple.com/documentation/xpc*](https://developer.apple.com/documentation/xpc)

11. macOS Apps With Embedded Daemons - DEV Community, acessado em junho
    > 12, 2025,
    > [*https://dev.to/brysontyrrell/macos-apps-with-embedded-daemons-333a*](https://dev.to/brysontyrrell/macos-apps-with-embedded-daemons-333a)

12. Writing a privileged helper tool with SMJobBless() - Stack Overflow,
    > acessado em junho 12, 2025,
    > [*https://stackoverflow.com/questions/9134841/writing-a-privileged-helper-tool-with-smjobbless*](https://stackoverflow.com/questions/9134841/writing-a-privileged-helper-tool-with-smjobbless)

13. A showcase for launching Privileged Helper via SMJobBless() and
    > communicating with it using XPC. - GitHub, acessado em junho 12,
    > 2025,
    > [*https://github.com/aronskaya/smjobbless*](https://github.com/aronskaya/smjobbless)

14. SMJobBless(\_:\_:\_:\_:) \| Apple Developer Documentation, acessado
    > em junho 12, 2025,
    > [*https://developer.apple.com/documentation/servicemanagement/smjobbless(\_:\_:\_:\_:)*](https://developer.apple.com/documentation/servicemanagement/smjobbless(_:_:_:_:))

15. smanna1729/NSXPCConnecton_SMJobBless: Communication between
    > SMJobBless helper tool and application using NSXPCConnection -
    > GitHub, acessado em junho 12, 2025,
    > [*https://github.com/smanna1729/NSXPCConnecton_SMJobBless*](https://github.com/smanna1729/NSXPCConnecton_SMJobBless)

16. Gain administration privileges with swift for a Mac Application -
    > Stack Overflow, acessado em junho 12, 2025,
    > [*https://stackoverflow.com/questions/34939243/gain-administration-privileges-with-swift-for-a-mac-application*](https://stackoverflow.com/questions/34939243/gain-administration-privileges-with-swift-for-a-mac-application)

17. Code sign your application - Unity - Manual, acessado em junho 12,
    > 2025,
    > [*https://docs.unity3d.com/6000.1/Documentation/Manual/macoscodesigning.html*](https://docs.unity3d.com/6000.1/Documentation/Manual/macoscodesigning.html)

18. How to check whether \"user\" cancelled Helper SM Job Bless password
    > dialog, acessado em junho 12, 2025,
    > [*https://stackoverflow.com/questions/77947472/how-to-check-whether-user-cancelled-helper-sm-job-bless-password-dialog*](https://stackoverflow.com/questions/77947472/how-to-check-whether-user-cancelled-helper-sm-job-bless-password-dialog)

19. Swift implementation of the Authorization Services framework -
    > GitHub, acessado em junho 12, 2025,
    > [*https://github.com/trilemma-dev/Authorized*](https://github.com/trilemma-dev/Authorized)

20. EvenBetterAuthorizationSample/App-Sandboxed/XPCService/XPCService.m
    > at master · brenwell/EvenBetterAuthorizationSample - GitHub,
    > acessado em junho 12, 2025,
    > [*https://github.com/brenwell/EvenBetterAuthorizationSample/blob/master/App-Sandboxed/XPCService/XPCService.m*](https://github.com/brenwell/EvenBetterAuthorizationSample/blob/master/App-Sandboxed/XPCService/XPCService.m)

21. My Mac App Vulnerability Journey: Strategies and Precision Hunting
    > Techniques, acessado em junho 12, 2025,
    > [*https://winslow1984.com/books/notes-and-insights/page/my-mac-app-vulnerability-journey-strategies-and-precision-hunting-techniques*](https://winslow1984.com/books/notes-and-insights/page/my-mac-app-vulnerability-journey-strategies-and-precision-hunting-techniques)

22. Job(s) Bless Us! Privileged Operations on macOS - Objective by the
    > Sea, acessado em junho 12, 2025,
    > [*https://objectivebythesea.org/v3/talks/OBTS_v3_jVashchenko.pdf*](https://objectivebythesea.org/v3/talks/OBTS_v3_jVashchenko.pdf)

23. objc2_core_audio - Rust - Docs.rs, acessado em junho 12, 2025,
    > [*https://docs.rs/objc2-core-audio*](https://docs.rs/objc2-core-audio)

24. Audio APIs, Part 1: Core Audio / macOS - bastibe, acessado em junho
    > 12, 2025,
    > [*https://bastibe.de/2017-06-17-audio-apis-coreaudio.html*](https://bastibe.de/2017-06-17-audio-apis-coreaudio.html)

25. mikeash.com: Why CoreAudio is Hard, acessado em junho 12, 2025,
    > [*https://www.mikeash.com/pyblog/why-coreaudio-is-hard.html*](https://www.mikeash.com/pyblog/why-coreaudio-is-hard.html)

26. kAudioHardwareIllegalOperation, acessado em junho 12, 2025,
    > [*https://developer.apple.com/documentation/coreaudio/kaudiohardwareillegaloperationerror*](https://developer.apple.com/documentation/coreaudio/kaudiohardwareillegaloperationerror)

27. Anyone have any luck capturing system audio from individual apps
    > using the Core Audio API? : r/MacOS - Reddit, acessado em junho
    > 12, 2025,
    > [*https://www.reddit.com/r/MacOS/comments/1kgnxf4/anyone_have_any_luck_capturing_system_audio_from/*](https://www.reddit.com/r/MacOS/comments/1kgnxf4/anyone_have_any_luck_capturing_system_audio_from/)

28. Elevating Privileges Safely - Apple Developer, acessado em junho 12,
    > 2025,
    > [*https://developer.apple.com/library/archive/documentation/Security/Conceptual/SecureCodingGuide/Articles/AccessControl.html*](https://developer.apple.com/library/archive/documentation/Security/Conceptual/SecureCodingGuide/Articles/AccessControl.html)

29. SMJobBless in objc2_service_management - Rust - Docs.rs, acessado em
    > junho 12, 2025,
    > [*https://docs.rs/objc2-service-management/latest/objc2_service_management/fn.SMJobBless.html*](https://docs.rs/objc2-service-management/latest/objc2_service_management/fn.SMJobBless.html)

30. Audio Hijack Release Notes - Rogue Amoeba, acessado em junho 12,
    > 2025,
    > [*https://rogueamoeba.com/audiohijack/releasenotes.php*](https://rogueamoeba.com/audiohijack/releasenotes.php)

31. macOS app like Audio Hijack that lives on menu bar? \| Audio Science
    > Review (ASR) Forum, acessado em junho 12, 2025,
    > [*https://www.audiosciencereview.com/forum/index.php?threads/macos-app-like-audio-hijack-that-lives-on-menu-bar.55971/*](https://www.audiosciencereview.com/forum/index.php?threads/macos-app-like-audio-hijack-that-lives-on-menu-bar.55971/)
