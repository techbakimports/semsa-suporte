# Changelog

Todas as alterações notáveis neste projeto serão documentadas neste arquivo.

## [1.1.9] - 2026-11-11

### Adicionado
- **Ferramentas > Gerenciadores de pacotes:** botões **Winget** e **Chocolatey**. Se o gerenciador já está instalado, o botão mostra a versão (e o clique mostra versão e caminho no log); se não está, mostra `Instalar ...` e instala com confirmação (exige Administrador e internet)
- Funções `Find-Winget`, `Get-WingetVersao`, `Install-Winget`, `Find-Chocolatey`, `Get-ChocolateyVersao` e `Install-Chocolatey`
- Instalação do winget: baixa o pacote oficial do GitHub `microsoft/winget-cli`, confere a assinatura da Microsoft e instala com `Add-AppxPackage`; só baixa as dependências (VCLibs e UI.Xaml) se o PC não as tiver; se falhar, tenta o módulo `Microsoft.WinGet.Client`. Roda em um PowerShell filho, com a janela responsiva e log em `%TEMP%`

### Alterado
- `Install-ProgramaFerramenta` usa `Find-Winget` (acha o winget mesmo fora do PATH) e `Install-Chocolatey` (antes o bootstrap rodava no processo da janela, que congelava durante a instalação)
- A mensagem de "winget não encontrado" em Ferramentas > Programas aponta para Ferramentas > Gerenciadores de pacotes

## [1.1.8] - 2026-11-11

### Corrigido
- **Ferramentas > Programas:** com o Transwiz instalado, o botão abria o **manual em PDF** em vez do programa. A busca pegava o primeiro atalho do Menu Iniciar com o nome do programa, e o instalador do Transwiz cria também um atalho para o "User Guide". Agora só vale atalho cujo destino é um `.exe` existente (lido do próprio atalho), são ignorados atalhos de desinstalador, ajuda, guia e manual, e o atalho de nome exato tem prioridade

## [1.1.7] - 2026-11-11

### Adicionado
- **Ferramentas > Programas**: botões **WizTree** e **Transwiz**. Abre o programa se já estiver instalado; senão pergunta e instala **pelo winget** (exige Administrador). Sem winget, o WizTree cai no Chocolatey (instalado antes se faltar); o Transwiz não tem fallback (o pacote do Chocolatey está desatualizado e quebrado) e o script avisa
- Descrição curta de cada programa abaixo do botão (campo `Desc` da tabela)
- Funções `Find-ProgramaFerramenta` (atalho do Menu Iniciar, depois `.exe`) e `Install-ProgramaFerramenta`; tabela `$listFerramentas` (uma linha por programa)

### Alterado
- Executor de processos genérico `Invoke-ExeAguardando` (stdout/stderr em arquivos, janela responsiva, `-OnTick`); `Invoke-PnpUtil` passou a usá-lo
- A janela **Ferramentas** monta o layout por seções e ajusta a própria altura

## [1.1.6] - 2026-11-11

### Adicionado
- **Ferramentas > Registro Remoto**: botões *Habilitar* e *Desabilitar* para o serviço `RemoteRegistry`, sob demanda e com exigência de Administrador. O *Desabilitar* limpa PCs padronizados em versões anteriores
- VERIFICAR: `[AVISO]` quando o `RemoteRegistry` está ativo (não conta como pendência)

### Alterado
- A padronização e o botão **Assist. Remota** **não ligam mais o `RemoteRegistry`**: ele não é necessário para o RDP nem para a Assistência Remota e é desabilitado por padrão no Windows (reduz a superfície de ataque). Ficam só `TermService`, `SessionEnv` e `UmRdpService`
- VERIFICAR: o `RemoteRegistry` deixou de ser exigido na lista de serviços da etapa 2 (antes aparecia `[FALTA]` em PCs com o RDP correto)
- Janela **Ferramentas** maior (360x320) para caber a nova seção

## [1.1.5] - 2026-11-11

### Adicionado
- **VERIFICAR PADRONIZAÇÃO, etapa 10 — Windows Update:** confere se o serviço `wuauserv` está desabilitado (padrão da Semsa, aplicado com o Wub). `[OK]` se desabilitado, `[FALTA]` se habilitado (com o tipo de início). Mostra também o serviço de reparo `WaaSMedicSvc` (`[AVISO]` se ativo, porque pode religar o Update), a política `NoAutoUpdate` e o servidor WSUS, quando existirem. Somente leitura, via registro

## [1.1.4] - 2026-11-09

### Adicionado
- Botão **Ferramentas** (grupo COMPUTADOR, abaixo de Ingresso Domínio): abre uma janela secundária de ferramentas extras
- **Ferramentas > Drivers**: *Exportar drivers* (backup dos drivers de terceiros para `Drivers_<PC>_<data>`, sem exigir Administrador) e *Importar drivers* (instala todos os `.inf` de uma pasta com confirmação, exige Administrador, grava a saída do `pnputil` em `%TEMP%`)
- Funções `Invoke-PnpUtil`, `Export-DriversSemsa` e `Import-DriversSemsa`; o `pnputil` roda em segundo plano com a janela responsiva, usa `Sysnative` em PowerShell 32 bits e a saída é lida em ANSI

### Alterado
- Espaçamento dos botões laterais reduzido em 1 a 2 pixels para caber o novo botão sem mudar o tamanho da janela

## [1.1.3] - 2026-10-23

Versão que consolida o script GUI-only (maio a outubro de 2026) e **unifica a numeração**: a partir daqui o script, o README, o CHANGELOG, o CLAUDE.md, a nota do Obsidian e a memória usam o mesmo número, e a cada modificação soma-se 1 no último dígito (próxima: 1.1.4). A versão aparece no título da janela. As entradas 1.3.0, 1.2.0 e 1.1.2 abaixo são do histórico anterior, com numeração descontinuada.

### Adicionado
- Botão **VERIFICAR PADRONIZAÇÃO**: checklist somente leitura das etapas (fuso, Assistência Remota, RDP, nome, domínio, conta admin, programas, certificado e ativação) com resumo e lista de pendências (`Get-PadronizacaoStatus`)
- Botão **Chave Office** (`Get-OfficeStatus`): status do Office via WMI, motivo do problema e contas Microsoft conectadas, sem depender do `ospp.vbs`
- **Tipo de ativação** (Retail, OEM, MAK, KMS) e linha `RESUMO` (chave, ativado, tipo) em **Chave Windows**, **Chave Office** e na etapa 9 da verificação
- **Winget** como terceira fonte de instalação (ao lado de Chocolatey e Standalone), com **fallback automático para o Chocolatey** quando o `winget` não é encontrado
- **Progresso de download** na instalação: rótulo com programa, percentual e tempo, e barra com granularidade por programa
- **Etapa 8 — Certificado**: instala `.cer`/`.crt` (arquivo ou pasta) em `LocalMachine\Root` via `certutil`, com conferência do thumbprint; verificação do certificado padrão da Semsa por thumbprint
- Modo Standalone: importa certificados `.cer/.crt/.pem` da pasta, limite de 10 minutos por instalador e pós-configuração do UltraVNC com `ultravnc.ini` (2026-05-29)
- Conta admin removida do grupo Usuários após a criação (2026-05-12)

### Alterado
- Versão do script no título da janela (`SEMSA Suporte v1.1.3`), definida em `$script:VersaoApp`
- Botão **INICIAR PADRONIZAÇÃO** dividido ao meio para abrigar o botão de verificação
- Script **GUI-only** (~1600 linhas): o menu de console e 14 funções foram removidos; `Set-AdminAccount` e `Test-ComputerName` extraídos (2026-05-23)
- Barra de progresso cobre todas as etapas da padronização (2026-07-27)
- Fuso horário fixo em Manaus (`SA Western Standard Time`), sem busca por cidade
- Plataforma-alvo passa a ser Windows 10/11
- Conta `admin` continua **sem senha, por decisão do mantenedor**; a senha da Zona é definida manualmente (a senha aleatória introduzida em 2026-08-31 foi revertida)
- `README.md` reescrito para refletir o script atual

### Corrigido
- **Firewall do RDP/Assistência Remota em Windows pt-BR:** o script usava `-DisplayGroup` em inglês e não encontrava regras; agora usa o identificador de grupo (`@FirewallAPI.dll,-28752`) e as regras `RemoteAssistance*`
- **`ExitCode` vazio no PowerShell 5.1:** sem `$null = $proc.Handle`, falhas do Chocolatey apareciam como `[OK]`
- Substituição de travessões (em-dash) por `--` para compatibilidade de codificação no PowerShell 5.1 (2026-05-19 e 2026-07-28)
- `slmgr` com codificação OEM para caracteres acentuados; Chrome com `--ignore-checksums`; fallback `net user` na criação do admin; UltraVNC interativo

### Removido
- Caminho de rede fixo (`\\balbina\f$\INSTALL_SEMSA-2023\`): o script não o contém mais; o modo Standalone usa a pasta escolhida na janela

---

## [1.3.0] - 2026-04-22

### Adicionado
- `Get-PCInfo`: detecção de discos físicos com tipo (HDD/SSD), capacidade, espaço usado/livre, status de saúde, temperatura (°C) e horas ligado via `Get-StorageReliabilityCounter`
- `Get-PCInfo`: listagem de impressoras físicas com filtro automático de impressoras virtuais (PDF, XPS, Fax, Microsoft, RustDesk, Virtual, Redirect, etc.)
- `Restart-ScriptAsAdmin`: nova função que orienta o usuário a reiniciar como Administrador — detecta execução via `iex` (memória) ou via arquivo `.ps1` e dá instruções diferentes para cada caso
- Verificação de privilégios administrativos na inicialização do script
- `CHANGELOG.md`: histórico de versões do projeto
- `fix.py`: utilitário Python para corrigir aspas tipográficas e espaços ausentes nos prefixos `[INFO]`, `[ERRO]`, `[SUCESSO]`

### Melhorado
- `Create-AdminAccount`: detecção do grupo Administradores por SID (`S-1-5-32-544`) em vez de nome hardcoded — compatível com Windows em PT-BR e EN-US
- `README.md`: reescrito com documentação completa e precisa de todas as funções, tabela de programas com IDs Winget/Chocolatey e problemas conhecidos

---

## [1.2.0] - 2026-04-20

### Adicionado
- Nova função `Get-PCInfo` que exibe informações completas do computador em um painel visual formatado:
  - **Sistema Operacional**: Nome completo do Windows via `Win32_OperatingSystem`
  - **Nome do Computador**: Obtido via `$env:COMPUTERNAME`
  - **Asset Tag**: Obtido via `Win32_SystemEnclosure`
  - **Versão da BIOS**: Obtida via `Win32_BIOS`
  - **Memória RAM**: Total em GB, tipo DDR (DDR3/DDR4/DDR5) e detalhes por slot (capacidade, velocidade, banco)
- Visual premium com cores diferenciadas por seção (Cyan, Green, DarkCyan, Yellow)
- Padding dinâmico para alinhamento correto independente do tamanho dos dados

### Alterado
- Menu principal: opções `[1] Obter Asset Tag` e `[2] Obter versão da BIOS` substituídas por `[1] Informações do PC` (destacada em verde)
- Opção `Sair` agora aparece em vermelho para destaque visual

### Mantido
- Funções originais `Get-MotherboardAssetTag` e `Get-BIOSVersion` permanecem no script para compatibilidade
- Todas as demais funções do script inalteradas

---

## [1.1.2] - 2026-04-14

### Alterado
- Renomeado script de `Semsa_v1.1.2.ps1` para `suporte.ps1`
- Documentação completa de todas as funções
