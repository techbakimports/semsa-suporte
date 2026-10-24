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
| `Get-PCInfo` | 4 | Hardware: SO, CPU, RAM, discos, impressoras (usa Get-CimInstance) |
| `Test-RemoteAssistance` | 180 | Diagnóstico de Assistência Remota com output colorido |
| `Get-NomeStatusLicenca` / `ConvertTo-CanalLicenca` / `Get-ResumoLicenca` | 245-267 | Texto do status, canal (Retail/OEM/MAK/KMS) e linha `RESUMO` da licença |
| `Get-WindowsLicenseInfo` | 274 | Licença do Windows via WMI (`SoftwareLicensingProduct`) |
| `Get-OfficeStatus` | 296 | Licença do Office via WMI + contas Microsoft conectadas (HKEY_USERS); sem `ospp.vbs` |
| `Get-PadronizacaoStatus` | 356 | Checklist somente leitura das etapas 1-9 (botão VERIFICAR) |
| `Set-AdminAccount` | 530 | Cria/ajusta a conta `admin` (**sem senha, de propósito**) |
| `Test-ComputerName` | 556 | Valida nome do PC (até 15 caracteres, sem espaços/inválidos) |
| `Show-PadronizacaoGUI` | 566 | GUI WinForms dark theme — entry point único; etapas, botões e executor `$runPkg` |

### GUI: etapas de padronização (dentro de Show-PadronizacaoGUI)
1. Fuso horário (Manaus)  2. Assistência Remota (registro, firewall por ID de grupo, serviços)  3. RDP
4. Renomear PC (opcional)  5. Ingressar domínio (opcional)  6. Conta admin  7. Programas (Chocolatey, Winget ou Standalone)
8. Certificado (`.cer`/`.crt` -> `LocalMachine\Root` via `certutil`, arquivo ou pasta escolhidos na GUI)

Botões: INICIAR PADRONIZACAO, **VERIFICAR PADRONIZACAO** (somente leitura) e laterais (Info do PC, Chave Windows, Chave Office, Ativar Win/Office, Assist. Remota, Testar Assist., Habilitar RDP, Fuso Horario, Conta Admin, Renomear PC, Ingresso Dominio).

### Instalação de programas
- Chocolatey e Winget usam a mesma lista `$listPrograms` (ids em `ChocoId`/`WingetId`, regex de detecção em `Pattern`). Winget ausente -> cai no Chocolatey com aviso.
- Standalone: pasta escolhida na GUI; importa `.cer/.crt/.pem`, executa os `.exe` (10 min cada) e aplica `ultravnc.ini` se existir na pasta.

## Programas pré-configurados
Chocolatey/Winget: Java 8 (Temurin JRE), WinRAR, VLC, Foxit Reader, PDF24, LibreOffice, Chrome, Firefox, UltraVNC. A pasta Standalone da Semsa também traz Kaspersky AV e Fusion.

## Requisitos
- Windows 10/11 (Windows 7/8 e Servers antigos não verificados), PowerShell 5.1
- Execução como Administrador
- Internet para Chocolatey/winget/ativação; rede local para domínio e, se usada, pasta Standalone

## Versão atual: 1.1.3
Mesma numeração em todos os lugares. **A cada modificação, somar 1 no último dígito** (1.1.3 -> 1.1.4 ...) em: `$script:VersaoApp` no topo do `suporte.ps1` (aparece no título da janela), cabeçalho do `README.md`, nova entrada no `CHANGELOG.md`, este arquivo, a nota do Obsidian e `project_overview.md` na memória.

## Regras
- Sempre testar localmente antes de atualizar o script no GitHub (é consumido via `irm | iex` em produção)
- `autorun.inf` é para distribuição via USB/CD — não remover
- Repositório público (lido via `irm`): **nunca** commitar senhas, `ultravnc.ini` ou certificados privados
- A conta `admin` sem senha é decisão do mantenedor: não reintroduzir senha aleatória sem pedir
- Não usar no PS 5.1: `??`, `?.`, `&&`, `||` (pipeline), `-AsHashtable`, ternário `?:`
- Em `Start-Process -PassThru`, fazer `$null = $proc.Handle` antes de ler `ExitCode`; não usar `return` dentro de `try/finally` em scriptblock
- Firewall: usar `-Group` (ID de recurso), nunca `-DisplayGroup` por nome (muda com o idioma)
