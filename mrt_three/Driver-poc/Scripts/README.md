# Scripts de Gerenciamento do Driver MRT

## 📝 Visão Geral

Scripts para build, instalação, teste e manutenção do driver de áudio MRT.

## 🛠️ Scripts Disponíveis

### 1. `build_driver.sh`
Compila o driver MRT Audio usando Xcode.

```bash
./Scripts/build_driver.sh
```

**O que faz:**
- Compila projeto Xcode em Release mode
- Cria universal binary (Intel + Apple Silicon)
- Gera driver em `build/Release/MRTAudioDriver.driver`

### 2. `install_driver.sh`
Instala o driver compilado no sistema.

```bash
sudo ./Scripts/install_driver.sh
```

**O que faz:**
- Verifica se driver foi compilado
- Remove driver antigo automaticamente
- Copia driver para `/Library/Audio/Plug-Ins/HAL/`
- Configura permissões corretas
- Reinicia Core Audio

### 3. `uninstall_driver.sh`
Remove o driver MRT Audio do sistema.

```bash
sudo ./Scripts/uninstall_driver.sh
```

**O que faz:**
- Para aplicações de áudio
- Remove driver de `/Library/Audio/Plug-Ins/HAL/`
- Reinicia Core Audio
- Confirma remoção

### 4. `update_driver.sh` ⭐ **RECOMENDADO**
Atualiza driver (desinstala antigo + instala novo).

```bash
sudo ./Scripts/update_driver.sh
```

**O que faz:**
- Executa desinstalação completa
- Aguarda Core Audio estabilizar
- Instala nova versão
- Valida instalação

### 5. `test_driver.sh`
Testa se o driver está funcionando corretamente.

```bash
./Scripts/test_driver.sh
```

**O que faz:**
- Verifica se driver está instalado
- Lista dispositivos de áudio
- Confirma se MRT Audio aparece no sistema
- Executa aplicação de controle Swift

## 🚀 Fluxo de Trabalho Recomendado

### Primeira Instalação
```bash
# 1. Compilar driver
./Scripts/build_driver.sh

# 2. Instalar driver
sudo ./Scripts/install_driver.sh

# 3. Testar instalação
./Scripts/test_driver.sh
```

### Atualizações
```bash
# 1. Compilar nova versão
./Scripts/build_driver.sh

# 2. Atualizar driver (remove antigo + instala novo)
sudo ./Scripts/update_driver.sh

# 3. Testar nova versão
./Scripts/test_driver.sh
```

### Desenvolvimento
```bash
# Ciclo rápido durante desenvolvimento:
./Scripts/build_driver.sh && sudo ./Scripts/update_driver.sh && ./Scripts/test_driver.sh
```

## 🔧 Resolução de Problemas

### Driver não aparece no sistema
```bash
# Reiniciar Core Audio manualmente
sudo killall -9 coreaudiod

# Verificar permissões
ls -la /Library/Audio/Plug-Ins/HAL/MRTAudioDriver.driver
```

### Erro de permissões
```bash
# Corrigir permissões manualmente
sudo chown -R root:wheel /Library/Audio/Plug-Ins/HAL/MRTAudioDriver.driver
sudo chmod -R 755 /Library/Audio/Plug-Ins/HAL/MRTAudioDriver.driver
```

### Build falha
```bash
# Limpar build e tentar novamente
rm -rf build/
./Scripts/build_driver.sh
```

## ⚠️ Notas Importantes

### Permissões Sudo
- `install_driver.sh`, `uninstall_driver.sh`, `update_driver.sh` requerem sudo
- `build_driver.sh` e `test_driver.sh` não requerem sudo

### Core Audio
- Scripts reiniciam automaticamente o coreaudiod
- Aplicações de áudio podem precisar ser reiniciadas
- Mudanças são imediatas após reinicialização

### Compatibilidade
- Scripts testados no macOS 12+ (Monterey+)
- Suportam Intel e Apple Silicon
- Requerem Xcode Command Line Tools

### Segurança
- Driver usa assinatura adhoc (desenvolvimento)
- Para distribuição, será necessária assinatura de desenvolvedor
- Sistema pode exigir aprovação manual na primeira instalação

## 📋 Status dos Scripts

| Script | Status | Funcionalidade |
|--------|--------|----------------|
| `build_driver.sh` | ✅ Funcional | Compila driver universal |
| `install_driver.sh` | ✅ Funcional | Instala com desinstalação automática |
| `uninstall_driver.sh` | ✅ Funcional | Remove driver completamente |
| `update_driver.sh` | ✅ Funcional | Atualização segura |
| `test_driver.sh` | ✅ Funcional | Validação completa |

Todos os scripts estão prontos para uso em produção! 🎉