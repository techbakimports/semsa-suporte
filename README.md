# Semsa Suporte

Este projeto é um script interativo em PowerShell (`Semsa_v1.1.2.ps1`) projetado para auxiliar no suporte e manutenção de computadores rodando Windows. Ele inclui funcionalidades de diagnóstico, configuração de sistema e utilidades importantes para otimizar o tempo no suporte técnico de equipamentos.

## Funcionalidades e Documentação das Funções

O script possui um menu interativo que oferece acesso centralizado a diversas funcionalidades:

1. **`Get-MotherboardAssetTag`**: Obtém e exibe a etiqueta de patrimônio (Asset Tag) registrada na BIOS da placa-mãe.
2. **`Get-BIOSVersion`**: Recupera a versão atual instalada da BIOS do sistema usando WMI.
3. **`Get-WindowsKey`**: Tenta obter a chave original de ativação do Windows através da ferramenta SoftwareLicensingService e exibe o status de expiração e licenciamento do Windows usando `slmgr.vbs`.
4. **`Activate-WindowsOffice`**: Executa o processo de ativação do Windows e/ou Office utilizando o método popular (via web irm).
5. **`Check-Drivers`**: Realiza uma varredura rigorosa e identifica se existem drivers com erro e qual o respectivo código de erro.
6. **`Set-TimeZoneOption`**: Solicita a entrada de um nome de fuso horário (ex. 'UTC-03:00') e permite atualizá-lo e aplicar ao sistema.
7. **`Disable-StartupPrograms`**: Desativa todos os aplicativos que inicializam junto com o Windows, exceto aqueles de suma importância, como UltraVNC, Fusion e outros serviços principais do Windows.
8. **`Disable-BackgroundApps`**: Aplica uma mudança diretamente no registro do Windows (para HKLM e HKCU) para desabilitar a execução em segundo plano globalmente para melhorar o desempenho.
9. **`Install-StandardPrograms`**: Oferece métodos diversos (`winget`, `chocolatey` ou Servidor Local) para a instalação rápida de um pacote fundamental de programas como Java, WinRAR, VLC, Foxit Reader, PDF24, Chrome, Firefox, LibreOffice e Kaspersky. Além de utilitários como Fusion e UltraVNC.
10. **`Enable-RemoteAssistance`**: Configura o registro, o firewall e os serviços relacionados (como `TermService`) para permitir uso livre de assistência e suporte remoto. Oferece opções alternativas de execução com elevação de privilégios.
11. **`Test-RemoteAssistance`**: Realiza diagnóstico rigoroso no computador (registros, serviços e firewall) validando se as chaves da configuração de Assistência Remota do passo anterior foram corretamente ativadas.
12. **`Enable-RemoteDesktop`**: Habilita a Área de Trabalho Remota configurando as restrições `fDenyTSConnections`.
13. **`Set-ComputerName`**: Permite alterar o nome de host da máquina e exige e aplica os passos de reinicialização.
14. **`Set-DomainName`**: Adiciona rapidamente a máquina local a um domínio especificado exigindo nome e credenciais da rede.
15. **`Enable-AdministratorAccount`**: Ativa a conta padrão desativada de `Administrator` (Administrador no Windows) alterando-a para um usuário `admin` e solicitando definição de senha de acesso.
16. **`Show-Menu`**: Exibe o menu texto interativo que orquestra todas as ações e chamadas disponíveis.
17. **`Restart-ScriptAsAdmin`**: Realiza verificações de permissões e relança o processo do PowerShell invocando um menu UAC de aprovação caso não esteja rodando em modo Administrador.

## Como Utilizar

Abra o PowerShell (preferencialmente como Administrador) e execute o script:
```powershell
.\Semsa_v1.1.2.ps1
```

> **Atenção:** Várias ações como instalação de programas e alteração de regras do Firewall e Registro exigem a execução em modo de elevação (Administrador).
