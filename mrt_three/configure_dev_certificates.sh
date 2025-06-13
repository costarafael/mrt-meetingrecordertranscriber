#!/bin/bash

# Script para verificar e configurar certificados de desenvolvimento
# Automatiza o processo de obter certificados via Xcode

echo "🔐 Configurando Certificados de Desenvolvimento..."
echo ""

# 1. Verificar se Xcode está instalado
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Xcode não encontrado. Instale o Xcode primeiro."
    exit 1
fi

echo "✅ Xcode encontrado: $(xcodebuild -version | head -1)"

# 2. Verificar contas de desenvolvedor no Xcode
echo "🔍 Verificando contas de desenvolvedor configuradas..."

# Tentar listar contas via xcodebuild
ACCOUNTS=$(defaults read com.apple.dt.Xcode 2>/dev/null | grep -A 5 "IDEProvisioningTeams" 2>/dev/null || echo "")

if [ -z "$ACCOUNTS" ]; then
    echo "⚠️  Nenhuma conta de desenvolvedor detectada no Xcode."
    echo ""
    echo "📋 CONFIGURE SUA CONTA DE DESENVOLVEDOR:"
    echo "   1. Abra o Xcode"
    echo "   2. Menu: Xcode > Settings (ou Preferences)"
    echo "   3. Aba: Accounts"
    echo "   4. Clique no '+' e adicione sua Apple ID"
    echo "   5. Selecione seu Time/Team de desenvolvimento"
    echo "   6. Clique em 'Manage Certificates...'"
    echo "   7. Clique no '+' e selecione 'Apple Development'"
    echo ""
    echo "🔄 Execute este script novamente após configurar."
    exit 1
fi

echo "✅ Conta de desenvolvedor detectada no Xcode"

# 3. Forçar refresh dos certificados
echo "🔄 Atualizando certificados de desenvolvimento..."

# Criar projeto temporário para forçar download de certificados
TEMP_PROJECT_DIR="/tmp/TempXcodeProject"
rm -rf "$TEMP_PROJECT_DIR"
mkdir -p "$TEMP_PROJECT_DIR"

cd "$TEMP_PROJECT_DIR"

# Criar projeto mínimo
cat > "TempApp.xcodeproj/project.pbxproj" << 'EOF'
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 54;
	objects = {
		1 = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = main.swift; sourceTree = "<group>"; };
		2 = {isa = PBXGroup; children = (1); sourceTree = "<group>"; };
		3 = {isa = PBXNativeTarget; buildConfigurationList = 5; buildPhases = (4); buildRules = (); dependencies = (); name = TempApp; productName = TempApp; productReference = 1; productType = "com.apple.product-type.tool"; };
		4 = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
		5 = {isa = XCConfigurationList; buildConfigurations = (6, 7); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; };
		6 = {isa = XCBuildConfiguration; buildSettings = {ALWAYS_SEARCH_USER_PATHS = NO; CLANG_ANALYZER_NONNULL = YES; CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE; CLANG_CXX_LANGUAGE_STANDARD = "gnu++14"; CLANG_CXX_LIBRARY = "libc++"; CLANG_ENABLE_MODULES = YES; CLANG_ENABLE_OBJC_ARC = YES; CLANG_ENABLE_OBJC_WEAK = YES; CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES; CLANG_WARN_BOOL_CONVERSION = YES; CLANG_WARN_COMMA = YES; CLANG_WARN_CONSTANT_CONVERSION = YES; CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES; CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR; CLANG_WARN_DOCUMENTATION_COMMENTS = YES; CLANG_WARN_EMPTY_BODY = YES; CLANG_WARN_ENUM_CONVERSION = YES; CLANG_WARN_INFINITE_RECURSION = YES; CLANG_WARN_INT_CONVERSION = YES; CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES; CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES; CLANG_WARN_OBJC_LITERAL_CONVERSION = YES; CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR; CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES; CLANG_WARN_RANGE_LOOP_ANALYSIS = YES; CLANG_WARN_STRICT_PROTOTYPES = YES; CLANG_WARN_SUSPICIOUS_MOVE = YES; CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE; CLANG_WARN_UNREACHABLE_CODE = YES; CLANG_WARN__DUPLICATE_METHOD_MATCH = YES; COPY_PHASE_STRIP = NO; DEBUG_INFORMATION_FORMAT = dwarf; ENABLE_STRICT_OBJC_MSGSEND = YES; ENABLE_TESTABILITY = YES; GCC_C_LANGUAGE_STANDARD = gnu11; GCC_DYNAMIC_NO_PIC = NO; GCC_NO_COMMON_BLOCKS = YES; GCC_OPTIMIZATION_LEVEL = 0; GCC_PREPROCESSOR_DEFINITIONS = ("DEBUG=1", "$(inherited)"); GCC_WARN_64_TO_32_BIT_CONVERSION = YES; GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR; GCC_WARN_UNDECLARED_SELECTOR = YES; GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE; GCC_WARN_UNUSED_FUNCTION = YES; GCC_WARN_UNUSED_VARIABLE = YES; MACOSX_DEPLOYMENT_TARGET = 13.0; MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE; MTL_FAST_MATH = YES; ONLY_ACTIVE_ARCH = YES; SDKROOT = macosx; SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG; SWIFT_OPTIMIZATION_LEVEL = "-Onone";}; name = Debug; };
		7 = {isa = XCBuildConfiguration; buildSettings = {CODE_SIGN_STYLE = Automatic; DEVELOPMENT_TEAM = ""; ENABLE_HARDENED_RUNTIME = YES; PRODUCT_NAME = "$(TARGET_NAME)"; SWIFT_VERSION = 5.0;}; name = Debug; };
		8 = {isa = PBXProject; attributes = {LastSwiftUpdateCheck = 1340; LastUpgradeCheck = 1340; TargetAttributes = {3 = {CreatedOnToolsVersion = 13.4;};};}; buildConfigurationList = 9; compatibilityVersion = "Xcode 9.3"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = 2; productRefGroup = 2; projectDirPath = ""; projectRoot = ""; targets = (3); };
		9 = {isa = XCConfigurationList; buildConfigurations = (6); defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug; };
	};
	rootObject = 8;
}
EOF

mkdir -p "TempApp.xcodeproj"
echo 'print("Hello")' > main.swift

# Tentar compilar para forçar download de certificados
echo "   Forçando download de certificados via build temporário..."
xcodebuild -project TempApp.xcodeproj -target TempApp -configuration Debug CODE_SIGN_STYLE=Automatic 2>/dev/null >/dev/null

cd - >/dev/null
rm -rf "$TEMP_PROJECT_DIR"

# 4. Verificar certificados agora
echo "🔍 Verificando certificados após refresh..."
CERTS=$(security find-identity -v -p codesigning | grep "Apple Development\|Mac Developer\|Developer ID")

if [ -n "$CERTS" ]; then
    echo "✅ Certificados de desenvolvimento encontrados:"
    echo "$CERTS"
    echo ""
    
    # Salvar certificado para uso
    SIGNING_IDENTITY=$(echo "$CERTS" | head -1 | sed 's/.*) "//' | sed 's/".*//')
    echo "🎯 Certificado selecionado: $SIGNING_IDENTITY"
    
    # Salvar em arquivo para scripts subsequentes
    echo "$SIGNING_IDENTITY" > .signing_identity
    echo "✅ Certificado salvo em .signing_identity"
    
else
    echo "❌ Ainda não há certificados disponíveis."
    echo ""
    echo "🔧 SOLUÇÕES ALTERNATIVAS:"
    echo ""
    echo "1. MÉTODO MANUAL NO XCODE:"
    echo "   • Abra Xcode"
    echo "   • Crie um novo projeto macOS"
    echo "   • Configure Team na aba Signing & Capabilities"
    echo "   • Build o projeto (Cmd+B)"
    echo "   • Isso deve gerar certificados automaticamente"
    echo ""
    echo "2. MÉTODO VIA LINHA DE COMANDO:"
    echo "   • Execute: fastlane match development"
    echo "   • Ou: xcrun altool --list-providers -u seu@email.com"
    echo ""
    echo "3. VERIFICAR KEYCHAIN:"
    echo "   • Abra Keychain Access"
    echo "   • Procure por 'Developer ID' ou 'Apple Development'"
    echo "   • Verifique se os certificados estão válidos"
    echo ""
    exit 1
fi

echo ""
echo "🎉 CERTIFICADOS CONFIGURADOS COM SUCESSO!"
echo ""
echo "🚀 PRÓXIMO PASSO:"
echo "   Execute: ./setup_real_xpc.sh"
echo "   Isso irá configurar e assinar o Core Audio TAP XPC real"