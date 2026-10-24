# Semsa Suporte

Ferramenta de suporte técnico em PowerShell para a **SEMSA / Manaus**. Abre uma janela (WinForms, tema escuro) que **padroniza computadores Windows** em uma única execução: fuso horário, Assistência Remota, RDP, nome do PC, domínio, conta admin, instalação de programas e certificado. Também **verifica** se a padronização já foi feita e mostra o **tipo de ativação** do Windows e do Office.

**Versão:** 1.1.3 · **Plataforma:** Windows 10/11 · **PowerShell:** 5.1 · [Changelog](CHANGELOG.md)

---

## Execução rápida

```powershell
# Execução remota (produção) — sem baixar o arquivo
irm https://raw.githubusercontent.com/techbakimports/semsa-suporte/refs/heads/main/suporte.ps1 | iex

# Execução local
powershell -ExecutionPolicy Bypass -File .\suporte.ps1

# Via batch (pede elevação UAC automaticamente)
SEMSA_SUPORTE.bat
```

> **Atenção ao `SEMSA_SUPORTE.bat`:** ele **não** roda o `suporte.ps1` local. Ele abre um PowerShell como administrador e baixa a versão publicada no GitHub (`irm ... | iex`). Precisa de internet e sempre executa o que está na branch `main`.

> **Cache do GitHub:** logo após um push, a URL da `main` pode servir a versão antiga por alguns minutos. Para testar uma versão exata, use a URL presa ao commit:
> `irm https://raw.githubusercontent.com/techbakimports/semsa-suporte/<hash-do-commit>/suporte.ps1 | iex`

---

## Requisitos

- **Windows 10 ou 11** (alvo do projeto). Windows 7/8 e Servers antigos **não foram verificados**: vários cmdlets usados (`Set-TimeZone`, `Get-LocalUser`, `Add-LocalGroupMember`, `Get-NetFirewallRule`) provavelmente não existem neles.
- **PowerShell 5.1**.
- **Executar como Administrador.** Sem isso o script abre, mas mostra um aviso, e registro, firewall, serviços, contas e instalação falham.
- **Internet** para: execução remota, Chocolatey, winget e o botão "Ativar Win/Office".
- **Rede local / domínio** para ingressar no domínio e, se for o caso, para acessar a pasta de instaladores do modo Standalone.

---

## A janela

```
┌ SEMSA SUPORTE ───────────────────────────────────────────────────────────┐
│ [Botões laterais] │ [Etapas da padronização] │ [Instalação de programas]  │
│  Info do PC       │  ☑ Fuso horário          │  ◉ Chocolatey              │
│  Chave Windows    │  ☑ Assistência Remota    │  ○ Winget                  │
│  Chave Office     │  ☑ RDP                   │    ☑ lista de programas    │
│  Ativar Win/Office│  ☑ Conta admin           │  ○ Standalones (pasta)     │
│  ...              │  ☑ Instalar programas    │  ☐ Instalar certificado    │
│                   │  Nome / Domínio (opc.)   │                            │
│ [ INICIAR PADRONIZAÇÃO ]  [ VERIFICAR PADRONIZAÇÃO ]                      │
│ ▓▓▓▓▓▓▓░░░░░░░░░  barra de progresso (+ % do download)                   │
│ LOG DE EXECUÇÃO (colorido)                                                │
└──────────────────────────────────────────────────────────────────────────┘
```

### Botões laterais (ações avulsas)

| Botão | O que faz |
|---|---|
| **Info do PC** | SO, nome, Asset Tag, serial, BIOS, CPU, RAM (tipo/velocidade/slot), discos físicos (HDD/SSD, saúde, temperatura, horas ligado) e impressoras físicas |
| **Chave Windows** | Chave OEM da BIOS (ou backup do registro), status via `slmgr /xpr` e **resumo da licença**: chave, ativado ou não, tipo (Retail/OEM/MAK/KMS), servidor KMS, dias restantes e se a BIOS tem chave embutida |
| **Chave Office** | Status do Office via WMI: produto, **resumo da licença** (chave, ativado, tipo), motivo do problema e contas Microsoft conectadas |
| **Ativar Win/Office** | Abre outra janela de administrador e executa `irm https://get.activated.win \| iex` (**script de terceiros**) |
| **Assist. Remota** | Habilita a Assistência Remota (mesma lógica da etapa 2) |
| **Testar Assist.** | Diagnóstico colorido da Assistência Remota (registro, serviço, firewall) |
| **Habilitar RDP** | Define `fDenyTSConnections = 0` |
| **Fuso Horário** | Define o fuso de Manaus |
| **Conta Admin** | Cria/ajusta a conta `admin` |
| **Renomear PC** | Pede o novo nome e renomeia (exige reinicialização) |
| **Ingresso Domínio** | Pede domínio, usuário e senha e ingressa (exige reinicialização) |

---

## Padronização automática (botão INICIAR PADRONIZAÇÃO)

As etapas rodam nesta ordem. Fuso, Assistência Remota, RDP, conta admin e programas têm checkbox; nome e domínio rodam só se o campo estiver preenchido.

| # | Etapa | O que faz |
|---|---|---|
| 1 | **Fuso horário** | `Set-TimeZone` para `SA Western Standard Time` (Manaus, UTC-04:00) |
| 2 | **Assistência Remota** | Registro (`fAllowToGetHelp`, `fDenyTSConnections`), remove política que bloqueia, habilita regras de firewall do RDP (por identificador de grupo, **independente do idioma**) e `RemoteAssistance*`, e deixa `TermService`, `SessionEnv`, `UmRdpService` e `RemoteRegistry` automáticos e rodando |
| 3 | **RDP** | `fDenyTSConnections = 0` (repete parte da etapa 2, sem problema) |
| 4 | **Renomear PC** *(opcional)* | Valida (até 15 caracteres, sem espaços nem `\ / : * ? " < > \|`, não só números) e executa `Rename-Computer` |
| 5 | **Domínio** *(opcional)* | `Add-Computer` com usuário e senha informados |
| 6 | **Conta admin** | Cria o usuário local `admin` **sem senha**, no grupo Administradores (detectado pelo SID `S-1-5-32-544`) e fora do grupo Usuários. Se já existe, não mexe na senha |
| 7 | **Programas** | Chocolatey, Winget ou Standalone (veja abaixo) |
| 8 | **Certificado** *(opcional)* | Instala `.cer`/`.crt` em Raiz Confiável da **máquina** (veja abaixo) |

No final, o log lembra a **etapa manual**: definir a senha do `admin` de acordo com a Zona. Se houve renomeação ou ingresso no domínio, o script oferece reiniciar.

### Conta admin sem senha

A conta `admin` é criada **sem senha, de propósito** (decisão do mantenedor); o técnico define a senha da Zona depois, manualmente. O Windows, por padrão, bloqueia login de rede e RDP para contas com senha em branco (`LimitBlankPasswordUse`), então até a senha ser definida a conta só entra no teclado da máquina. A verificação mostra `[FALTA] Senha da Zona definida` enquanto a conta nunca teve senha.

> Não coloque senhas no código: o repositório é lido sem autenticação (`irm`). Ver [Segurança](#segurança).

---

## Instalação de programas (etapa 7)

Três modos, escolhidos por botão de rádio. Chocolatey e Winget usam **a mesma lista** e os mesmos checkboxes.

| Programa | Chocolatey | Winget |
|---|---|---|
| Java (JRE 8) | `Temurin8jre` | `EclipseAdoptium.Temurin.8.JRE` |
| WinRAR | `winrar` | `RARLab.WinRAR` |
| VLC | `vlc` | `VideoLAN.VLC` |
| Foxit Reader | `FoxitReader` | `Foxit.FoxitReader` |
| PDF24 | `pdf24` | `geeksoftwareGmbH.PDF24Creator` |
| LibreOffice | `libreoffice-still` | `TheDocumentFoundation.LibreOffice` |
| Google Chrome | `GoogleChrome` (`--ignore-checksums`) | `Google.Chrome` |
| Firefox | `Firefox` | `Mozilla.Firefox.pt-BR` |
| UltraVNC (GUI) | `ultravnc` | `uvncbvba.UltraVNC` |

O **UltraVNC** é sempre o último e instalado de forma **interativa** (abre o instalador para você configurar porta/senha).

### Chocolatey (padrão)
Instala o Chocolatey se não existir e instala cada programa com `choco install <id> -y`. O Chrome usa `--ignore-checksums` porque o Google atualiza o instalador antes do pacote.

### Winget (Windows 10 1809+/11)
Instala com `winget install --exact --source winget --silent`. **Se o `winget` não for encontrado, o script avisa no log e usa o Chocolatey automaticamente.** Se o winget existe mas está com problema (sem internet, repositório quebrado), não há fallback: cada programa falha com `[ERRO]` e o código.

Diferenças em relação ao Chocolatey:
- **LibreOffice:** o winget só tem a versão atual (não existe a "still").
- **Firefox:** no winget a instalação é em pt-BR.
- **Chrome:** sem `--ignore-checksums`; pode falhar por hash divergente quando a Google atualiza antes do manifesto.

### Standalone (pasta de instaladores)
O técnico escolhe, pela janela, uma pasta com os instaladores. O script então:
1. Importa para `LocalMachine\Root` os certificados `.cer`, `.crt` e `.pem` da pasta;
2. Executa cada `.exe` em ordem alfabética, com **limite de 10 minutos** por instalador (se estourar, segue para o próximo);
3. Se houver um `ultravnc.ini` na pasta, aplica-o no UltraVNC (veja abaixo).

Não há caminho fixo no script: o caminho é sempre escolhido na janela.

### Progresso
Choco e winget rodam por um executor único que lê a saída e mostra, à esquerda da barra, o programa atual e o progresso (`[3/9] LibreOffice — baixando 45% (01:12)`). O **Chocolatey** informa o percentual do download. O **winget** não informa percentual quando a saída é redirecionada, então mostra só o tempo decorrido.

---

## Certificado (etapa 8)

Na seção **INSTALAR CERTIFICADO**, escolha um arquivo (`.cer`/`.crt`) ou uma pasta. O script instala cada um com `certutil -addstore -f Root` (funciona em qualquer Windows) e confere se o *thumbprint* apareceu em `Cert:\LocalMachine\Root`. A etapa roda com qualquer modo de instalação.

> **Onde ver:** o `certlm.msc` mostra o repositório da **máquina**. O `certmgr.msc` mostra a visão do **usuário**, que também inclui os certificados da máquina; por isso aparecer no `certmgr.msc` **não prova** que foi instalado para a máquina inteira.

---

## Verificar padronização (somente leitura)

O botão **VERIFICAR PADRONIZAÇÃO** não altera nada. Ele confere cada etapa e mostra `[OK]`, `[FALTA]`, `[AVISO]` ou `[INFO]`, com um resumo e a lista de pendências no final:

| Etapa | Como confere |
|---|---|
| 1. Fuso | `TimeZoneInfo.Local` = `SA Western Standard Time` |
| 2. Assistência Remota | Registro (e política que bloqueia), regras `RemoteAssistance*` do firewall, serviços rodando |
| 3. RDP | `fDenyTSConnections = 0`, regras de firewall do RDP, porta 3389 escutando |
| 4. Nome | Compara com o campo da janela (campo vazio = só mostra o atual) |
| 5. Domínio | Compara com o campo da janela (campo vazio = só mostra o atual) |
| 6. Conta admin | Existe, habilitada, no grupo Administradores, fora de Usuários, senha da Zona definida |
| 7. Programas | Procura cada um no registro de desinstalação (HKLM 64/32 bits e HKCU) pelo nome; no UltraVNC confere também o serviço `uvnc_service` e a porta **8888** |
| 8. Certificado | Certificado padrão da Semsa (por thumbprint) e os arquivos escolhidos na janela, em `LocalMachine\Root` |
| 9. Ativação | Windows e Office: chave, ativado, tipo |

Limites: só os 9 programas da lista são conferidos (por nome); os checkboxes não influenciam a verificação; a porta 8888 do UltraVNC é o padrão da Semsa e está fixa no código.

---

## Ativação: tipo da licença

Os botões **Chave Windows**, **Chave Office** e a etapa 9 da verificação mostram uma linha como:

```
RESUMO  : Chave: SIM (final 3V66T) | Ativado: SIM | Tipo: Retail
```

- **Tipo:** `Retail`, `Retail (assinatura Microsoft 365)`, `OEM`, `MAK (volume)`, `KMS (volume)` ou `Avaliação (temporária)`. É o canal que o próprio Windows/Office registra para a licença.
- **Ativado:** `SIM`, `EM TOLERANCIA` ou `NAO`.
- **Limites:** uma licença digital do Windows 10/11 (vinculada ao hardware ou à conta) aparece como **Retail**, e o Windows mostra uma chave parcial genérica. No Office só ficam disponíveis os **5 últimos caracteres** da chave. Em Microsoft 365 com licença **por conta**, o script mostra a conta conectada (por usuário logado), mas não a validade da assinatura: confirme em *Arquivo > Conta* no Office.
- O Office é lido via WMI (`SoftwareLicensingProduct` / `OfficeSoftwareProtectionProduct`), **sem depender do `ospp.vbs`**.

---

## UltraVNC: `ultravnc.ini`

No modo **Standalone**, se existir um arquivo chamado exatamente `ultravnc.ini` na pasta escolhida, o script, depois de instalar, para o serviço `uvnc_service`, copia o arquivo para a pasta do UltraVNC e reinicia o serviço.

- **Como gerar:** configure o UltraVNC numa máquina de referência (porta, senha, permissões) e copie o `ultravnc.ini` da pasta de instalação dele. Use a **mesma versão** do UltraVNC nas máquinas.
- **Só funciona no modo Standalone.** Em Chocolatey/winget o arquivo não é aplicado.
- O log mostra `[OK]` mesmo que o serviço não reinicie (os comandos ignoram erros).
- O script **não** abre a porta 8888 no firewall.
- **Nunca coloque o `ultravnc.ini` no GitHub:** ele guarda a senha do VNC em formato reversível. Mantenha-o apenas na pasta de instaladores.

---

## Estrutura do projeto

```
semsa-suporte/
├── suporte.ps1          # Script principal (GUI WinForms)
├── SEMSA_SUPORTE.bat    # Wrapper: eleva UAC e executa a versão publicada no GitHub
├── autorun.inf          # AutoRun para distribuição via USB/CD (não remover)
├── CHANGELOG.md         # Histórico de versões
├── CLAUDE.md            # Instruções do projeto para o assistente de código
└── README.md
```

### Funções de `suporte.ps1`

| Função | Papel |
|---|---|
| `Get-PCInfo` | Informações de hardware |
| `Test-RemoteAssistance` | Diagnóstico da Assistência Remota |
| `Get-NomeStatusLicenca`, `ConvertTo-CanalLicenca`, `Get-ResumoLicenca` | Tradução de status e canal de licença |
| `Get-WindowsLicenseInfo` | Licença do Windows |
| `Get-OfficeStatus` | Licença do Office e contas conectadas |
| `Get-PadronizacaoStatus` | Checklist da verificação |
| `Set-AdminAccount` | Cria/ajusta a conta `admin` |
| `Test-ComputerName` | Valida o nome do computador |
| `Show-PadronizacaoGUI` | Janela principal — **ponto de entrada**; contém as etapas, os botões e o executor de instalação |

---

## Desenvolvimento

Regras para quem altera o script:

- **PowerShell 5.1.** Não usar `??`, `?.`, `&&`, `||` (pipeline), `-AsHashtable` nem o operador ternário `?:`.
- **Codificação: UTF-8 sem BOM** e textos do script em **ASCII** (sem acento ou travessão). Isso é crítico para o PowerShell 5.1 e para `irm | iex`.
- **Testar localmente antes de publicar:** o script é consumido direto do GitHub em produção.
- Em `Start-Process -PassThru -NoNewWindow`, faça `$null = $proc.Handle` logo depois de iniciar; sem isso o `ExitCode` vem vazio e falhas parecem sucesso.
- Em scriptblocks, não use `return` dentro de `try/finally`; capture o valor antes e retorne fora.
- Nomes de grupo de firewall mudam com o idioma do Windows; use o identificador (`-Group "@FirewallAPI.dll,-28752"`), não `-DisplayGroup`.

---

## Segurança

- O repositório é lido **sem autenticação** (`irm`); trate-o como **público**. Não commite senhas, chaves, o `ultravnc.ini` nem arquivos de certificado privado.
- A senha da conta `admin` não está no código: é definida manualmente depois (etapa manual).
- O botão **Ativar Win/Office** baixa e executa código de um site de terceiros (`get.activated.win`).
- As instalações via Chocolatey e winget baixam e executam instaladores da internet, com os privilégios de administrador da sessão.

---

## Problemas conhecidos

| Problema | Descrição |
|---|---|
| Sem log em arquivo | O log fica só na janela e some ao fechar |
| Janela pode congelar | Instalações longas rodam na mesma thread da interface (a janela é atualizada, mas pode ficar lenta) |
| Percentual do Chocolatey | O leitor de progresso foi testado com saída simulada, ainda sem validação com o Chocolatey real |
| Winget sem percentual | Só mostra tempo decorrido |
| Sem rollback | Se uma etapa falhar no meio, nada é desfeito |
| `ultravnc.ini` só no Standalone | E sem aviso se o serviço não reiniciar; porta 8888 não é aberta no firewall |
| Verificação de programas por nome | Programa instalado com nome diferente no registro aparece como `[FALTA]` |
| Chave Office por conta | Mostra a conta conectada, não a validade da assinatura |
| Windows 7/8 | Não verificado; provavelmente incompatível |
