# semsa-suporte

## Objetivo
Script PowerShell de suporte técnico corporativo para a Semsa/Manaus. Padroniza configuração de PCs, instala programas, habilita RDP/VNC/assistência remota e faz ingresso em domínio.

## Stack
- PowerShell 5.1+ (script principal com 2197 linhas)
- .NET Framework: System.Windows.Forms, System.Drawing, System.Security.Cryptography
- Batch (.bat) como wrapper para elevação UAC

## Comandos
```powershell
# Execução remota (produção)
irm https://raw.githubusercontent.com/techbakimports/semsa-suporte/refs/heads/main/suporte.ps1 | iex

# Execução local
powershell -ExecutionPolicy Bypass -File .\suporte.ps1

# Via batch (eleva UAC automaticamente)
.\SEMSA_SUPORTE.bat
```

## Funções principais (suporte.ps1)
| Função | Descrição |
|--------|-----------|
| `Get-PCInfo` | Hardware: SO, CPU, RAM, discos, impressoras |
| `Get-WindowsKey` | Recupera chave de ativação Windows |
| `Activate-WindowsOffice` | Ativa Windows/Office |
| `Install-StandardPrograms` | Instala pacote corporativo (Winget/Chocolatey/rede local) |
| `Enable-RemoteAssistance` | Configura assistência remota |
| `Enable-RemoteDesktop` | Habilita RDP |
| `Set-ComputerName` | Renomeia o computador |
| `Set-DomainName` | Ingressa em domínio Active Directory |
| `Create-AdminAccount` | Cria usuário administrador local |
| `Show-PadronizacaoGUI` | Interface gráfica Windows Forms para padronização completa |

## Programas corporativos pré-configurados
Java 8, WinRAR, VLC, Foxit Reader, PDF24, LibreOffice, Chrome, Firefox, Kaspersky AV, UltraVNC, Fusion

## Requisitos
- Windows 7 SP1+ / Server 2008 R2+, PowerShell 5.1+
- Execução como Administrador (obrigatório para todas as funções)
- Rede local `\\balbina\f$\INSTALL_SEMSA-2023\` disponível para instalação corporativa

## Regras
- Sempre testar localmente antes de atualizar o script no GitHub (é consumido via `irm | iex` em produção)
- `autorun.inf` é para distribuição via USB/CD — não remover
- O caminho de rede `\\balbina\f$\` é específico da infraestrutura Semsa — não generalizar
