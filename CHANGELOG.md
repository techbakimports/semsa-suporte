# Changelog

Todas as alteracoes notaveis neste projeto serao documentadas neste arquivo.

## [1.2.0] - 2026-04-20

### Adicionado
- Nova funcao `Get-PCInfo` que exibe informacoes completas do computador em um painel visual formatado:
  - **Sistema Operacional**: Nome completo do Windows via `Win32_OperatingSystem`
  - **Nome do Computador**: Obtido via `$env:COMPUTERNAME`
  - **Asset Tag**: Obtido via `Win32_SystemEnclosure`
  - **Versao da BIOS**: Obtida via `Win32_BIOS`
  - **Memoria RAM**: Total em GB, tipo DDR (DDR3/DDR4/DDR5) e detalhes por slot (capacidade, velocidade, banco)
- Visual premium com box-drawing characters (bordas duplas e simples)
- Cores diferenciadas por secao (Cyan, Green, DarkCyan, Yellow)
- Padding dinamico para alinhamento correto independente do tamanho dos dados

### Alterado
- Menu principal: opcoes `[1] Obter Asset Tag` e `[2] Obter versao da BIOS` foram substituidas por `[1] Informacoes do PC` (destacada em verde)
- Todas as opcoes do menu foram renumeradas de 1 a 15
- Opcao `Sair` agora aparece em vermelho para destaque visual

### Mantido
- Funcoes originais `Get-MotherboardAssetTag` e `Get-BIOSVersion` permanecem no script para compatibilidade
- Todas as demais funcoes do script inalteradas

## [1.1.2] - 2026-04-14

### Alterado
- Renomeado script de `Semsa_v1.1.2.ps1` para `suporte.ps1`
- Documentacao completa de todas as funcoes
