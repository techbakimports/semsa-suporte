# Changelog

Todas as alterações notáveis neste projeto serão documentadas neste arquivo.

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
