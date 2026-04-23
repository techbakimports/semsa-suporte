# Semsa Suporte

Script PowerShell interativo para automatizar tarefas comuns de suporte técnico em ambientes corporativos Windows. Centraliza diagnósticos, configurações e instalações em um único script executável localmente ou remotamente.

**Versão:** 1.1.2 · **Plataforma:** Windows 7 SP1+ / Server 2008 R2+ · **PowerShell:** 5.1+

---

## Execução Rápida

```powershell
# Execução remota (recomendado — sem precisar baixar o arquivo)
irm https://raw.githubusercontent.com/techbakimports/semsa-suporte/refs/heads/main/suporte.ps1 | iex

# Via arquivo local (requer ExecutionPolicy adequada)
powershell -ExecutionPolicy Bypass -File .\suporte.ps1

# Via batch (eleva UAC automaticamente)
SEMSA_SUPORTE.bat
```

> **Importante:** Diversas funções requerem execução como **Administrador** (instalação de programas, firewall, registro, ingresso em domínio). O script detecta isso automaticamente e orienta o usuário.

---

## Menu de Opções

| Opção | Função | Descrição |
|-------|---------|-----------|
| 1 | Informações do PC | SO, serial, CPU, RAM, discos físicos, impressoras |
| 2 | Chave do Windows | Recupera chave OEM/registro + verifica status da licença |
| 3 | Ativar Windows/Office | Executa ativador via `get.activated.win` |
| 4 | Definir fuso horário | Busca por nome de cidade ou padrão UTC |
| 5 | Instalar programas padrão | Pacote corporativo via Winget, Chocolatey ou servidor local |
| 6 | Habilitar Assistência Remota | Configura registro, firewall e serviços |
| 7 | Testar Assistência Remota | Diagnóstico completo da configuração |
| 8 | Habilitar Área de Trabalho Remota | Habilita RDP via registro |
| 9 | Alterar nome do computador | Renomeia e reinicia |
| 10 | Definir domínio | Ingressa no Active Directory |
| 11 | Criar conta admin | Cria usuário local sem senha no grupo Administradores |
| 12 | Sair | — |

---

## Funções em Detalhe

### `Get-PCInfo`
Exibe um painel completo de hardware:
- Sistema operacional, nome da máquina, Asset Tag, número de série
- Processador
- **Discos físicos**: modelo, tipo (HDD/SSD), capacidade, espaço usado/livre, status de saúde, temperatura (°C), horas ligado
- **RAM**: total em GB, tipo (DDR3/DDR4/DDR5), velocidade (MHz) e slot de cada módulo
- **Impressoras**: lista apenas físicas (filtra PDF, XPS, Fax, Microsoft, virtual, redirect, etc.)

### `Get-WindowsKey`
Tenta recuperar a chave do Windows via `SoftwareLicensingService` (chave OEM gravada na BIOS) com fallback pelo registro (`BackupProductKeyDefault`). Opcionalmente executa `slmgr /xpr` para verificar validade da licença.

### `Activate-WindowsOffice`
Executa `irm https://get.activated.win | iex` — ativador popular para Windows e Office.

### `Set-TimeZoneOption`
Solicita nome de cidade ou padrão UTC (ex: `"Manaus"`, `"Sao Paulo"`, `"UTC-04:00"`) e aplica o fuso correspondente com `Set-TimeZone`.

### `Install-StandardPrograms`
Instala o pacote padrão corporativo com 3 métodos à escolha:

| Programa | Winget ID | Choco ID |
|----------|-----------|----------|
| Java (JRE 8) | `Microsoft.Java` | `jdk8` |
| WinRAR | `WinRAR.WinRAR` | `winrar` |
| VLC | `VideoLAN.VLC` | `vlc` |
| Foxit Reader | `FoxitSoftware.FoxitReader` | `foxitreader` |
| PDF24 | `PDF24.PDF24` | `pdf24` |
| LibreOffice | `LibreOffice.LibreOffice` | `libreoffice` |
| Google Chrome | `Google.Chrome` | `googlechrome` |
| Mozilla Firefox | `Mozilla.Firefox` | `firefox` |
| Kaspersky AV | `Kaspersky.KasperskyAntiVirus` | `kaspersky` |
| UltraVNC | `UltraVNC.UltraVNC` | `ultravnc` |
| Fusion | `Fusion.Fusion` | — |

O método **Servidor Local** usa caminhos de rede `\\balbina\f$\INSTALL_SEMSA-2023\` (específico do ambiente SEMSA).

### `Enable-RemoteAssistance`
Configura Assistência Remota com 4 métodos em cascata:
1. Chaves de registro (`fAllowToGetHelp`, `fDenyTSConnections`)
2. Regras de firewall (suporta nomes PT-BR e EN-US)
3. Serviços: `TermService`, `SessionEnv`, `UmRdpService`, `RemoteRegistry`
4. Fallback via `SystemPropertiesRemote.exe` (GUI) quando não há privilégios

### `Test-RemoteAssistance`
Diagnóstico com output colorido verificando registro, serviço `TermService` e regras de firewall. Sinaliza problemas em vermelho e configurações corretas em verde.

### `Enable-RemoteDesktop`
Define `fDenyTSConnections = 0` no registro para habilitar RDP.

### `Set-ComputerName`
Usa `Rename-Computer -Force -Restart` para renomear e reiniciar imediatamente.

### `Set-DomainName`
Solicita domínio, usuário e senha, verifica se a máquina já está no domínio, e executa `Add-Computer` com reinicialização.

### `Create-AdminAccount`
Cria usuário local `admin` sem senha. Detecta o grupo Administradores pelo SID `S-1-5-32-544` (compatível com PT-BR e EN-US) e adiciona o usuário ao grupo.

### `Restart-ScriptAsAdmin`
Detecta se o script está rodando sem privilégios e orienta o usuário:
- **Execução via `iex`** (na memória): exibe instruções para abrir PowerShell como admin
- **Execução via arquivo**: cria atalho `.lnk` temporário e abre o Explorer no local

---

## Estrutura do Projeto

```
semsa-suporte/
├── suporte.ps1           # Script principal — todas as funções e menu
├── SEMSA_SUPORTE.bat     # Wrapper batch com elevação UAC automática
├── autorun.inf           # AutoRun para distribuição via USB/CD
├── fix.py                # Utilitário Python para corrigir aspas especiais no script
├── test.ps1              # Validação de sintaxe do script principal
└── README.md
```

---

## Requisitos

- Windows 7 SP1 ou superior (Windows 10/11 recomendado)
- PowerShell 5.1 (nativo no Windows 10/11)
- Execução como **Administrador** para a maioria das funções
- Acesso à internet para execução remota e instalação via Winget/Chocolatey
- Acesso à rede `\\balbina\` para instalação via Servidor Local (ambiente SEMSA)

---

## Problemas Conhecidos

| Problema | Descrição |
|----------|-----------|
| Winget não detecta falha | Reporta sucesso mesmo quando a instalação falha silenciosamente |
| Caminhos hardcoded | `\\balbina\f$\INSTALL_SEMSA-2023\` não é portável fora do ambiente SEMSA |
| Nomes de arquivo com data | Ex: `"vlc-3.0.21 BAIXADO 19.08.2024.exe"` — quebra quando o arquivo for atualizado |
| Sem logging | Apenas output no console, sem arquivo de log persistente |
