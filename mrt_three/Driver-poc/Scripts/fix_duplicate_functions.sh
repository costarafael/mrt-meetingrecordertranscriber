#!/bin/bash

# =============================================================================
# CORREÇÃO CRÍTICA: Remover funções duplicadas
# =============================================================================

echo "🔧 CORRIGINDO FUNÇÕES DUPLICADAS NO DRIVER"
echo "=========================================="

DRIVER_FILE="/Users/rafaelaredes/Documents/mrt_macos/mrt_three/Driver-poc/MRTAudioDriver/MRTAudioDriver.c"

# Backup
cp "$DRIVER_FILE" "${DRIVER_FILE}.backup.duplicate.$(date +%Y%m%d_%H%M%S)"

echo "✅ Backup criado"

# Criar script Python para remover duplicatas
cat > /tmp/fix_duplicates.py << 'EOF'
import re

def fix_duplicate_functions():
    """
    Remove funções duplicadas que estão causando problemas
    """
    
    with open('/Users/rafaelaredes/Documents/mrt_macos/mrt_three/Driver-poc/MRTAudioDriver/MRTAudioDriver.c', 'r') as f:
        content = f.read()
    
    print("🔍 Procurando funções duplicadas...")
    
    # Encontrar a PRIMEIRA implementação (linha 709) - esta tem o Multi-Output Device
    first_impl_start = content.find('static OSStatus MRT_SendAudioToDefaultOutput(const Float32* audioData, UInt32 frameCount)')
    
    if first_impl_start == -1:
        print("❌ Primeira implementação não encontrada")
        return
    
    # Encontrar onde termina a primeira implementação
    # Procurar pela próxima função que começa com "static" ou "//" ou função similar
    search_from = first_impl_start + 100
    first_impl_end = content.find('\n\n// Função para criar Multi-Output Device', search_from)
    
    if first_impl_end == -1:
        first_impl_end = content.find('\n\nstatic OSStatus MRT_CreateMultiOutputDevice', search_from)
    
    if first_impl_end == -1:
        # Tentar encontrar o final da função de outra forma
        brace_count = 0
        in_function = False
        i = first_impl_start
        while i < len(content):
            if content[i] == '{':
                brace_count += 1
                in_function = True
            elif content[i] == '}':
                brace_count -= 1
                if brace_count == 0 and in_function:
                    first_impl_end = i + 1
                    break
            i += 1
    
    # Encontrar a SEGUNDA implementação (linha ~4982)
    second_impl_start = content.find('static OSStatus MRT_SendAudioToDefaultOutput(const Float32* audioData, UInt32 frameCount)', first_impl_end)
    
    if second_impl_start == -1:
        print("❌ Segunda implementação não encontrada")
        return
    
    print(f"✅ Primeira implementação encontrada em: {first_impl_start}")
    print(f"✅ Segunda implementação encontrada em: {second_impl_start}")
    
    # Encontrar onde termina a segunda implementação
    brace_count = 0
    in_function = False
    i = second_impl_start
    second_impl_end = -1
    while i < len(content):
        if content[i] == '{':
            brace_count += 1
            in_function = True
        elif content[i] == '}':
            brace_count -= 1
            if brace_count == 0 and in_function:
                second_impl_end = i + 1
                break
        i += 1
    
    if second_impl_end == -1:
        print("❌ Fim da segunda implementação não encontrado")
        return
    
    print(f"✅ Fim da segunda implementação: {second_impl_end}")
    
    # Remover a segunda implementação (mais nova, problemática)
    content_before = content[:second_impl_start]
    content_after = content[second_impl_end:]
    
    # Procurar e remover também as funções auxiliares duplicadas
    aux_functions_to_remove = [
        'static AudioDeviceID MRT_GetPhysicalOutputDevice(void)',
        'static OSStatus MRT_InitializeOutputUnit(AudioDeviceID deviceID)',
        'static void MRT_InitializePassthroughSystem(void)',
        'static void MRT_CleanupPassthroughSystem(void)'
    ]
    
    for func_signature in aux_functions_to_remove:
        func_start = content_after.find(func_signature)
        if func_start != -1:
            # Encontrar fim da função
            brace_count = 0
            in_function = False
            i = func_start
            func_end = -1
            while i < len(content_after):
                if content_after[i] == '{':
                    brace_count += 1
                    in_function = True
                elif content_after[i] == '}':
                    brace_count -= 1
                    if brace_count == 0 and in_function:
                        func_end = i + 1
                        break
                i += 1
            
            if func_end != -1:
                print(f"✅ Removendo função duplicada: {func_signature}")
                content_after = content_after[:func_start] + content_after[func_end:]
    
    # Juntar conteúdo sem a segunda implementação
    new_content = content_before + content_after
    
    # Verificar se ainda há duplicatas
    count = new_content.count('static OSStatus MRT_SendAudioToDefaultOutput(')
    if count > 1:
        print(f"⚠️  Ainda há {count} implementações - tentando limpeza mais agressiva")
        
        # Remover todas as implementações após a primeira
        first_occurrence = new_content.find('static OSStatus MRT_SendAudioToDefaultOutput(')
        if first_occurrence != -1:
            # Encontrar todas as próximas ocorrências
            remaining_content = new_content[first_occurrence:]
            next_occurrence = remaining_content.find('static OSStatus MRT_SendAudioToDefaultOutput(', 1)
            
            if next_occurrence != -1:
                # Manter apenas até a primeira implementação completa
                actual_first = first_occurrence
                # Encontrar fim da primeira implementação
                brace_count = 0
                in_function = False
                i = 0
                first_end = -1
                content_from_first = new_content[actual_first:]
                
                while i < len(content_from_first):
                    if content_from_first[i] == '{':
                        brace_count += 1
                        in_function = True
                    elif content_from_first[i] == '}':
                        brace_count -= 1
                        if brace_count == 0 and in_function:
                            first_end = actual_first + i + 1
                            break
                    i += 1
                
                if first_end != -1:
                    # Manter conteúdo antes + primeira implementação + conteúdo após segunda
                    before_first = new_content[:actual_first]
                    first_impl = new_content[actual_first:first_end]
                    
                    # Pular toda a área problemática e pegar conteúdo limpo depois
                    clean_after_idx = new_content.find('\n\n#pragma mark Device IO Operations', first_end)
                    if clean_after_idx == -1:
                        clean_after_idx = new_content.find('static OSStatus\tBlackHole_DoIOOperation', first_end)
                    
                    if clean_after_idx != -1:
                        after_clean = new_content[clean_after_idx:]
                        new_content = before_first + first_impl + '\n\n' + after_clean
                        print("✅ Limpeza agressiva aplicada")
    
    # Salvar arquivo corrigido
    with open('/Users/rafaelaredes/Documents/mrt_macos/mrt_three/Driver-poc/MRTAudioDriver/MRTAudioDriver.c', 'w') as f:
        f.write(new_content)
    
    # Verificar resultado final
    final_count = new_content.count('static OSStatus MRT_SendAudioToDefaultOutput(')
    print(f"✅ Correção concluída! Implementações restantes: {final_count}")
    
    if final_count == 1:
        print("✅ Sucesso - apenas uma implementação restante")
    else:
        print("⚠️  Ainda há duplicatas - verificação manual necessária")

if __name__ == "__main__":
    fix_duplicate_functions()
EOF

python3 /tmp/fix_duplicates.py

echo ""
echo "🧪 Verificando resultado..."
grep -c "static OSStatus MRT_SendAudioToDefaultOutput" "$DRIVER_FILE"

echo ""
echo "✅ CORREÇÃO APLICADA!"
echo "==================="
echo ""
echo "🚀 PRÓXIMOS PASSOS:"
echo "1. bash Scripts/build_driver.sh"
echo "2. sudo bash Scripts/install_driver.sh"
echo "3. Testar novamente o passthrough"

rm -f /tmp/fix_duplicates.py