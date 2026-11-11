# semsa-suporte

## Objetivo
Script PowerShell de suporte técnico corporativo para a Semsa/Manaus. Abre uma GUI que padroniza a configuração de PCs (fuso, Assistência Remota, RDP, nome, domínio, conta admin), instala programas (Chocolatey, Winget ou pasta Standalone), instala certificado em Raiz Confiável, verifica se a padronização está OK e mostra o tipo de ativação do Windows/Office.

## Stack
- PowerShell 5.1 (script principal com ~1900 linhas)
- .NET Framework: System.Windows.Forms, System.Drawing, System.Security.Cryptography
- Batch (.bat) como wrapper para elevação UAC (executa a versão publicada no GitHub, não o arquivo local)
- Encoding: UTF-8 sem BOM (crítico para PS 5.1 e `irm | iex`); textos do script em ASCII (sem acento/travessão)

## Comandos
```powershell
# Execução remota (produção)
irm https://raw.githubusercontent.com/techbakimports/semsa-suporte/refs/heads/main/suporte.ps1 | iex

# Execução remota presa a um commit (evita o cache da main)
irm https://raw.githubusercontent.com/techbakimports/semsa-suporte/<hash>/suporte.ps1 | iex

# Execução local
powershell -ExecutionPolicy Bypass -File .\suporte.ps1

# Via batch (eleva UAC; baixa e roda a versão do GitHub)
.\SEMSA_SUPORTE.bat
```

## Funções (suporte.ps1) — GUI-only
| Função | Linha | Descrição |
|--------|-------|-----------|
| `Get-PCInfo` | 7 | Hardware: SO, CPU, RAM, discos, impressoras (usa Get-CimInstance) |
| `Test-RemoteAssistance` | 183 | Diagnóstico de Assistência Remota com output colorido |
| `Get-NomeStatusLicenca` / `ConvertTo-CanalLicenca` / `Get-ResumoLicenca` | 248-270 | Texto do status, canal (Retail/OEM/MAK/KMS) e linha `RESUMO` da licença |
| `Get-WindowsLicenseInfo` | 277 | Licença do Windows via WMI (`SoftwareLicensingProduct`) |
| `Get-OfficeStatus` | 299 | Licença do Office via WMI + contas Microsoft conectadas (HKEY_USERS); sem `ospp.vbs` |
| `Get-PadronizacaoStatus` | 359 | Checklist somente leitura das etapas 1-10 (botão VERIFICAR); a 10 é o Windows Update (esperado **desabilitado**, padrão Semsa com o Wub) |
| `Set-AdminAccount` | 556 | Cria/ajusta a conta `admin` (**sem senha, de propósito**) |
| `Test-ComputerName` | 582 | Valida nome do PC (até 15 caracteres, sem espaços/inválidos) |
| `Invoke-PnpUtil` | 593 | Roda o `pnputil.exe` (Sysnative em PS 32 bits), devolve código e saída (ANSI) sem congelar a janela |
| `Export-DriversSemsa` / `Import-DriversSemsa` | 628-652 | Exporta (`/export-driver *`) e importa (`/add-driver "pasta\*.inf" /subdirs /install`) drivers de terceiros |
| `Show-PadronizacaoGUI` | 664 | GUI WinForms dark theme — entry point único; etapas, botões, janela Ferramentas e executor `$runPkg` |

### GUI: etapas de padronização (dentro de Show-PadronizacaoGUI)
1. Fuso horário (Manaus)  2. Assistência Remota (registro, firewall por ID de grupo, serviços)  3. RDP
4. Renomear PC (opcional)  5. Ingressar domínio (opcional)  6. Conta admin  7. Programas (Chocolatey, Winget ou Standalone)
8. Certificado (`.cer`/`.crt` -> `LocalMachine\Root` via `certutil`, arquivo ou pasta escolhidos na GUI)

Botões: INICIAR PADRONIZACAO, **VERIFICAR PADRONIZACAO** (somente leitura) e laterais (Info do PC, Chave Windows, Chave Office, Ativar Win/Office, Assist. Remota, Testar Assist., Habilitar RDP, Fuso Horario, Conta Admin, Renomear PC, Ingresso Dominio, **Ferramentas**).

### Janela Ferramentas (botão em COMPUTADOR, abaixo de Ingresso Dominio)
Janela secundária modal (padrão `$dlg`, como Renomear/Domínio): cada ferramenta é um botão que grava a escolha em `$script:ferramentaEscolhida`; a execução roda depois no log da janela principal. Hoje só tem **Drivers**: *Exportar* (cria `<pasta>\Drivers_<PC>_<data>`; **não exige admin**) e *Importar* (exige admin, pede confirmação, usa uma chamada `pnputil` e grava a saída em `%TEMP%\SemsaSuporte_drivers_*.log`; código 3010 = reinício necessário). Só exporta drivers de terceiros (`oemNN.inf`), não os nativos do Windows.

### Instalação de programas
- Chocolatey e Winget usam a mesma lista `$listPrograms` (ids em `ChocoId`/`WingetId`, regex de detecção em `Pattern`). Winget ausente -> cai no Chocolatey com aviso.
- Standalone: pasta escolhida na GUI; importa `.cer/.crt/.pem`, executa os `.exe` (10 min cada) e aplica `ultravnc.ini` se existir na pasta.

## Programas pré-configurados
Chocolatey/Winget: Java 8 (Temurin JRE), WinRAR, VLC, Foxit Reader, PDF24, LibreOffice, Chrome, Firefox, UltraVNC. A pasta Standalone da Semsa também traz Kaspersky AV e Fusion.

## Requisitos
- Windows 10/11 (Windows 7/8 e Servers antigos não verificados), PowerShell 5.1
- Execução como Administrador
- Internet para Chocolatey/winget/ativação; rede local para domínio e, se usada, pasta Standalone

## Versão atual: 1.1.5
Mesma numeração em todos os lugares. **A cada modificação, somar 1 no último dígito** (1.1.5 -> 1.1.6 ...) em: `$script:VersaoApp` no topo do `suporte.ps1` (aparece no título da janela), cabeçalho do `README.md`, nova entrada no `CHANGELOG.md`, este arquivo, a nota do Obsidian e `project_overview.md` na memória.

## Regras
- Sempre testar localmente antes de atualizar o script no GitHub (é consumido via `irm | iex` em produção)
- `autorun.inf` é para distribuição via USB/CD — não remover
- Repositório público (lido via `irm`): **nunca** commitar senhas, `ultravnc.ini` ou certificados privados
- A conta `admin` sem senha é decisão do mantenedor: não reintroduzir senha aleatória sem pedir
- Não usar no PS 5.1: `??`, `?.`, `&&`, `||` (pipeline), `-AsHashtable`, ternário `?:`
- Em `Start-Process -PassThru`, fazer `$null = $proc.Handle` antes de ler `ExitCode`; não usar `return` dentro de `try/finally` em scriptblock
- Firewall: usar `-Group` (ID de recurso), nunca `-DisplayGroup` por nome (muda com o idioma)
