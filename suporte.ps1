
# Primeiro, definimos todas as funcoes


function Get-PCInfo {
    Clear-Host
    Write-Host ""
    Write-Host "  ==========================================================" -ForegroundColor Cyan
    Write-Host "               INFORMACOES DO COMPUTADOR" -ForegroundColor Yellow
    Write-Host "  ==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  [INFO] Coletando informacoes do sistema..." -ForegroundColor DarkGray
    Write-Host ""

    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
    $osName = $osInfo.Caption
    $computerName = $env:COMPUTERNAME

    $assetTag = Get-WmiObject -Class Win32_SystemEnclosure | Select-Object -ExpandProperty SMBIOSAssetTag
    if (-not $assetTag) { $assetTag = "Nao disponivel" }

    $serialNumber = Get-WmiObject -Class Win32_BIOS | Select-Object -ExpandProperty SerialNumber
    if (-not $serialNumber) { $serialNumber = "Nao disponivel" }

    $cpuInfo = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
    $cpuName = if ($cpuInfo -and $cpuInfo.Name) { $cpuInfo.Name.Trim() } else { "Nao disponivel" }

    $ramModules = Get-CimInstance Win32_PhysicalMemory
    $totalRAM = 0
    $ramTypes = @()

    if ($ramModules) {
        foreach ($ram in $ramModules) {
            $totalRAM += $ram.Capacity
            $memType = $ram.SMBIOSMemoryType
            if ($memType -eq 24) { $ramTypes += "DDR3" }
            elseif ($memType -eq 26) { $ramTypes += "DDR4" }
            elseif ($memType -eq 34) { $ramTypes += "DDR5" }
            else { $ramTypes += "Outro" }
        }
    }
    
    $totalRAMGB = [math]::Round($totalRAM / 1073741824, 1)
    $ramTypeStr = ($ramTypes | Select-Object -Unique) -join ", "
    if (-not $ramTypeStr) { $ramTypeStr = "Desconhecido" }

    $diskDetails = @()
    try {
        $physDisks = Get-PhysicalDisk -ErrorAction Stop | Sort-Object DeviceId
        foreach ($pd in $physDisks) {
            $diskNum = [int]$pd.DeviceId
            $usedBytes = 0; $freeBytes = 0
            try {
                $parts = Get-Partition -DiskNumber $diskNum -ErrorAction SilentlyContinue
                foreach ($p in $parts) {
                    try {
                        $vol = Get-Volume -Partition $p -ErrorAction SilentlyContinue
                        if ($vol -and $vol.Size -gt 0) {
                            $usedBytes += ($vol.Size - $vol.SizeRemaining)
                            $freeBytes += $vol.SizeRemaining
                        }
                    } catch {}
                }
            } catch {}
            $mediaLabel = switch ($pd.MediaType) {
                "HDD" { "HDD" } "SSD" { "SSD" } "SCM" { "SCM" } default { "Desconhecido" }
            }
            $healthLabel = switch ($pd.HealthStatus) {
                "Healthy" { "Saudavel" } "Warning" { "Atencao" } "Unhealthy" { "Com Falha" } default { "Desconhecido" }
            }
            $healthColor = switch ($pd.HealthStatus) {
                "Healthy" { "Green" } "Warning" { "Yellow" } "Unhealthy" { "Red" } default { "DarkGray" }
            }
            $tempC = $null; $hours = $null
            try {
                $rel = $pd | Get-StorageReliabilityCounter -ErrorAction SilentlyContinue
                if ($rel -and $rel.Temperature -gt 0) { $tempC = $rel.Temperature }
                if ($rel -and $rel.PowerOnHours -gt 0) { $hours = $rel.PowerOnHours }
            } catch {}
            $tempColor = if ($null -ne $tempC -and $tempC -gt 55) { "Red" } elseif ($null -ne $tempC -and $tempC -gt 45) { "Yellow" } else { "DarkCyan" }
            $diskDetails += [PSCustomObject]@{
                Model       = $pd.FriendlyName
                MediaType   = $mediaLabel
                SizeGB      = [math]::Round($pd.Size / 1GB, 1)
                UsedGB      = [math]::Round($usedBytes / 1GB, 1)
                FreeGB      = [math]::Round($freeBytes / 1GB, 1)
                Health      = $healthLabel
                HealthColor = $healthColor
                TempC       = $tempC
                TempColor   = $tempColor
                Hours       = $hours
            }
        }
    } catch {}

    $realPrinters = @()
    try {
        $virtualPattern = 'PDF|XPS|Fax|Microsoft|Foxit|PDF24|Adobe|OneNote|CutePDF|DoPDF|Bullzip|PrimoPDF|novaPDF|RustDesk|Virtual|Remote|Redirect'
        $virtualPorts  = @('PORTPROMPT:', 'FILE:', 'nul', 'NUL:')
        $realPrinters = Get-WmiObject -Class Win32_Printer -ErrorAction SilentlyContinue |
            Where-Object { $_.PortName -notin $virtualPorts -and $_.Name -notmatch $virtualPattern }
    } catch {}

    $labelColor = "Cyan"
    $valueColor = "White"
    $separatorColor = "DarkGray"

    Write-Host "  SISTEMA OPERACIONAL: " -ForegroundColor $labelColor -NoNewline
    Write-Host $osName -ForegroundColor $valueColor

    Write-Host "  NOME DO COMPUTADOR:  " -ForegroundColor $labelColor -NoNewline
    Write-Host $computerName -ForegroundColor Green

    Write-Host "  ASSET TAG:           " -ForegroundColor $labelColor -NoNewline
    Write-Host $assetTag -ForegroundColor $valueColor

    Write-Host "  NUMERO DE SERIE:     " -ForegroundColor $labelColor -NoNewline
    Write-Host $serialNumber -ForegroundColor $valueColor

    Write-Host "  PROCESSADOR:         " -ForegroundColor $labelColor -NoNewline
    Write-Host $cpuName -ForegroundColor $valueColor

    Write-Host "  DISCOS:              " -ForegroundColor $labelColor -NoNewline
    if ($diskDetails.Count -gt 0) {
        Write-Host "$($diskDetails.Count) disco(s) detectado(s)" -ForegroundColor $valueColor
        $diskIdx = 1
        foreach ($d in $diskDetails) {
            $line = '      Disco {0}: {1} ({2}) | {3} GB total | Usado: {4} GB | Livre: {5} GB' -f $diskIdx, $d.Model, $d.MediaType, $d.SizeGB, $d.UsedGB, $d.FreeGB
            Write-Host $line -ForegroundColor DarkCyan -NoNewline
            Write-Host " | Saude: $($d.Health)" -ForegroundColor $d.HealthColor -NoNewline
            if ($null -ne $d.TempC) {
                Write-Host " | $($d.TempC)°C" -ForegroundColor $d.TempColor -NoNewline
            }
            if ($null -ne $d.Hours) {
                Write-Host " | $($d.Hours)h" -ForegroundColor DarkCyan -NoNewline
            }
            Write-Host ""
            $diskIdx++
        }
    } else {
        Write-Host "Nao foi possivel coletar informacoes de disco" -ForegroundColor DarkGray
    }

    Write-Host "  MEMORIA RAM:         " -ForegroundColor $labelColor -NoNewline
    $ramDisplay = ('Total: {0} GB | Tipo: {1}' -f $totalRAMGB, $ramTypeStr)
    Write-Host $ramDisplay -ForegroundColor $valueColor

    if ($ramModules) {
        $moduleIndex = 1
        foreach ($module in $ramModules) {
            $capGB = [math]::Round($module.Capacity / 1GB, 0)
            $speed = $module.Speed
            $bank = $module.BankLabel
            
            $memType = $module.SMBIOSMemoryType
            if ($memType -eq 24) { $ddrType = "DDR3" }
            elseif ($memType -eq 26) { $ddrType = "DDR4" }
            elseif ($memType -eq 34) { $ddrType = "DDR5" }
            else { $ddrType = "Outro" }

            $modDisplay = ('      Slot {0}: {1}GB {2} @ {3}MHz ({4})' -f $moduleIndex, $capGB, $ddrType, $speed, $bank)
            Write-Host $modDisplay -ForegroundColor DarkCyan
            $moduleIndex++
        }
    }

    Write-Host "  IMPRESSORAS:         " -ForegroundColor $labelColor -NoNewline
    if ($realPrinters -and @($realPrinters).Count -gt 0) {
        Write-Host "$(@($realPrinters).Count) encontrada(s)" -ForegroundColor $valueColor
        foreach ($p in $realPrinters) {
            $pColor  = if ($p.WorkOffline) { "DarkGray" } else { "DarkCyan" }
            $pSuffix = if ($p.WorkOffline) { " (offline)" } else { "" }
            Write-Host "      $($p.Name)$pSuffix" -ForegroundColor $pColor
        }
    } else {
        Write-Host "Nenhuma impressora fisica encontrada" -ForegroundColor DarkGray
    }

    Write-Host "  ==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  [SUCESSO] Coleta de informacoes concluida com sucesso!" -ForegroundColor Green
    Write-Host ""
}

function Get-WindowsKey {
    Write-Output " [INFO] Obtendo chave do Windows..."
    try {
        $productKey = (Get-WmiObject -Class SoftwareLicensingService).OA3xOriginalProductKey
        if ($productKey) {
            Write-Output " [SUCESSO] Chave do Windows encontrada: $productKey"
        } else {
            # Tenta metodo alternativo para obter a chave
            $regKey = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform" -Name BackupProductKeyDefault -ErrorAction SilentlyContinue).BackupProductKeyDefault
            if ($regKey) {
                Write-Output " [SUCESSO] Chave do Windows encontrada: $regKey"
            } else {
                Write-Output " [ERRO] Nao foi possivel encontrar a chave do Windows."
            }
        }

        # Pergunta se deseja verificar o status da licenca
        $checkStatus = Read-Host "`nDeseja verificar o status da licenca do Windows? (S/N)"
        if ($checkStatus -eq 'S' -or $checkStatus -eq 's') {
            Write-Output "`n[INFO] Verificando status da licenca usando slmgr..."
            
            try {
                # Usar o comando slmgr /xpr para verificar a data de expiracao da licenca
                $tempFile = [System.IO.Path]::GetTempFileName()
                
                # Executar o comando slmgr /xpr e redirecionar a saida para um arquivo temporario
                Start-Process "cscript.exe" -ArgumentList "//Nologo $env:windir\system32\slmgr.vbs /xpr" -NoNewWindow -Wait -RedirectStandardOutput $tempFile
                
                # Ler o resultado do arquivo temporario
                $slmgrResult = Get-Content -Path $tempFile -Raw
                
                # Limpar o arquivo temporario
                Remove-Item -Path $tempFile -Force
                
                # Exibir o resultado formatado
                Write-Host "`nStatus da Licenca do Windows:" -ForegroundColor Cyan
                
                # Verificar se a licenca esta ativa com base no texto retornado
                if ($slmgrResult -match "permanente|permanent|nao expira|will not expire") {
                    Write-Host $slmgrResult -ForegroundColor Green
                } elseif ($slmgrResult -match "expirou|expired") {
                    Write-Host $slmgrResult -ForegroundColor Red
                } else {
                    # Para licencas com data de expiracao ou outros estados
                    Write-Host $slmgrResult -ForegroundColor Yellow
                }
                
                # Obter informacoes adicionais sobre o produto
                $productInfo = Get-WmiObject -Class Win32_OperatingSystem | Select-Object Caption
                Write-Host "Produto: $($productInfo.Caption)" -ForegroundColor Cyan
            } catch {
                Write-Host "`n[ERRO] Falha ao executar o comando slmgr: $($_.Exception.Message)" -ForegroundColor Red
                
                # Fallback para o metodo antigo em caso de falha
                Write-Host " [INFO] Usando metodo alternativo para verificar a licenca..." -ForegroundColor Yellow
                
                $licenseInfo = Get-WmiObject -Class SoftwareLicensingProduct | 
                    Where-Object { $_.PartialProductKey -and $_.Name -like "*Windows*" } |
                    Select-Object -Property LicenseStatus, Description, ExpirationDate

                $status = switch ($licenseInfo.LicenseStatus) {
                    0 { "Nao licenciado" }
                    1 { "Licenciado" }
                    2 { "Periodo inicial de carencia" }
                    3 { "Periodo adicional de carencia" }
                    4 { "Periodo de carencia nao genuino" }
                    5 { "Notificacao" }
                    6 { "Periodo de carencia estendido" }
                    default { "Status desconhecido" }
                }

                Write-Host "`nStatus da Licenca: $status" -ForegroundColor $(if ($status -eq "Licenciado") { "Green" } else { "Yellow" })
                Write-Host "Produto: $($licenseInfo.Description)"
                
                # Verifica e exibe a data de expiracao
                if ($licenseInfo.ExpirationDate) {
                    $expirationDate = [Management.ManagementDateTimeConverter]::ToDateTime($licenseInfo.ExpirationDate)
                    Write-Host "Data de Expiracao: $($expirationDate.ToString('dd/MM/yyyy HH:mm:ss'))" -ForegroundColor Yellow
                } else {
                    Write-Host "Data de Expiracao: Licenca permanente ou nao disponivel" -ForegroundColor Green
                }
            }
        }
    } catch {
        Write-Output " [ERRO] Erro ao obter informacoes da licenca: $($_.Exception.Message)"
    }
}

function Activate-WindowsOffice {
    Write-Output " [INFO] Iniciando ativacao do Windows/Office..."
    irm https://get.activated.win | iex
}



function Set-TimeZoneOption {
    $fusoEscolhido = Read-Host "Digite o nome da cidade ou fuso horario (ex: 'Manaus', 'Sao Paulo' ou 'UTC-04:00')"
    
    $fusoValido = Get-TimeZone -ListAvailable | Where-Object { $_.DisplayName -match $fusoEscolhido -or $_.Id -match $fusoEscolhido } | Select-Object -First 1

    if ($fusoValido) {
        Set-TimeZone -Id $fusoValido.Id
        Write-Host " [SUCESSO] Fuso horario configurado para: $($fusoValido.DisplayName)" -ForegroundColor Green
    } else {
        Write-Host " [ERRO] Nenhum fuso horario encontrado para '$fusoEscolhido'. Tente novamente com outro nome." -ForegroundColor Red
    }
}





function Install-StandardPrograms {
    Write-Output " [INFO] Instalando programas padrao..."
    
    # Caminho do servidor local onde estao os instaladores
    $serverPath = "\\servidor\instaladores"  # Ajuste este caminho conforme seu ambiente
    
    # Menu de escolha do metodo de instalacao
    Write-Host "`n=== Metodo de Instalacao ===" -ForegroundColor Cyan
    Write-Host "1. Windows Package Manager (winget)"
    Write-Host "2. Chocolatey"
    Write-Host "3. Servidor Local"
    Write-Host "4. Cancelar"
    
    $choice = Read-Host "`nEscolha o metodo de instalacao (1-4)"
    
    $programs = @(
        @{
            Id="Oracle.JavaRuntimeEnvironment"
            Name="Java"
            ChocoId="Temurin8jre"
            LocalPath="\\balbina\f$\INSTALL_SEMSA-2023\_Jav\jre-8u421-windows-x64.exe"
            LocalArgs="/s"
        },
        @{
            Id="RARLab.WinRAR"
            Name="WinRAR"
            ChocoId="winrar"
            LocalPath="\\balbina\f$\INSTALL_SEMSA-2023\_Winrar\winrar-x64-611br.exe"
            LocalArgs="/S"
        },
        @{
            Id="VideoLAN.VLC"
            Name="VLC"
            ChocoId="vlc"
            LocalPath="$\\balbina\f$\INSTALL_SEMSA-2023\_VLC\vlc-3.0.21-win64 BAIXADO 19.08.2024.exe"
            LocalArgs="/S"
        },
        @{
            Id="FoxitSoftware.FoxitReader"
            Name="Foxit Reader"
            ChocoId="foxitreader"
            LocalPath="$\\balbina\f$\INSTALL_SEMSA-2023\_Foxit\FoxitPDFReader202423_L10N_Setup_Prom BAIXADO 12.08.2024.exe"
            LocalArgs="/silent"
        },
        @{
            Id="geeksoftwareGmbH.PDF24Creator"
            Name="PDF24"
            ChocoId="pdf24"
            LocalPath="\\balbina\f$\INSTALL_SEMSA-2023\_PDF24\pdf24-creator-11.18.0-x64 BAIXADO 19.08.2024.exe"
            LocalArgs="/quiet"
        },
        @{
            Id="TheDocumentFoundation.LibreOffice"
            Name="LibreOffice"
            ChocoId="libreoffice"
            LocalPath="\\balbina\f$\INSTALL_SEMSA-2023\LibreOffice_24.8.4_Win_x86-64 BAIXADO 27.01.2025.exe"
            LocalArgs="/quiet"
        },
        @{
            Id="Google.Chrome"
            Name="Google Chrome"
            ChocoId="googlechrome"
            LocalPath="\\balbina\f$\INSTALL_SEMSA-2023\_Navegadores\ChromeStandaloneSetup64.exe"
            LocalArgs="/silent /install"
        },
        @{
            Id="Mozilla.Firefox"
            Name="Mozilla Firefox"
            ChocoId="firefox"
            LocalPath="\\balbina\f$\INSTALL_SEMSA-2023\_Navegadores\Firefox Installer.exe"
            LocalArgs="-ms"
        },
        @{
            Id="Kaspersky.KasperskyAntiVirus"
            Name="Kaspersky"
            ChocoId="kaspersky"
            LocalPath="\\balbina\suporte\Kasper ok\Kasper12-Desktop-2024-06-27.exe"
            LocalArgs="/s"
        }
    )

    switch ($choice) {
        "1" { # Winget
            if (!(Get-Command winget -ErrorAction SilentlyContinue)) {
                Write-Host " [ERRO] Winget nao encontrado. Escolha outro metodo." -ForegroundColor Red
                return
            }
            
            foreach ($program in $programs) {
                Write-Output " [INFO] Instalando $($program.Name) via winget..."
                try {
                    winget install --id $program.Id --exact --silent --accept-source-agreements --accept-package-agreements
                    Write-Output " [SUCESSO] $($program.Name) instalado com sucesso."
                } catch {
                    Write-Output " [ERRO] Falha ao instalar $($program.Name): $($_.Exception.Message)"
                }
            }
        }
        
        "2" { # Chocolatey
            # Verifica se o Chocolatey esta instalado
            if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
                Write-Host " [INFO] Chocolatey nao encontrado. Instalando..."
                try {
                    Set-ExecutionPolicy Bypass -Scope Process -Force
                    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
                    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
                } catch {
                    Write-Host " [ERRO] Falha ao instalar Chocolatey. Escolha outro metodo." -ForegroundColor Red
                    return
                }
            }
            
            foreach ($program in $programs) {
                Write-Output " [INFO] Instalando $($program.Name) via Chocolatey..."
                try {
                    choco install $program.ChocoId -y
                    Write-Output " [SUCESSO] $($program.Name) instalado com sucesso."
                } catch {
                    Write-Output " [ERRO] Falha ao instalar $($program.Name): $($_.Exception.Message)"
                }
            }
        }
        
        "3" { # Servidor Local
            foreach ($program in $programs) {
                Write-Output " [INFO] Instalando $($program.Name) via servidor local..."
                if (Test-Path $program.LocalPath) {
                    try {
                        Start-Process -FilePath $program.LocalPath -ArgumentList $program.LocalArgs -Wait
                        Write-Output " [SUCESSO] $($program.Name) instalado com sucesso."
                    } catch {
                        Write-Output " [ERRO] Falha ao instalar $($program.Name): $($_.Exception.Message)"
                    }
                } else {
                    Write-Output " [ERRO] Instalador nao encontrado: $($program.LocalPath)"
                }
            }
        }
        
        "4" { # Cancelar
            Write-Host "Instalacao cancelada pelo usuario." -ForegroundColor Yellow
            return
        }
        
        default {
            Write-Host "Opcao invalida." -ForegroundColor Red
            return
        }
    }

    # Instalacao do UltraVNC e Fusion
    Write-Host "`n=== Instalando programas adicionais ===" -ForegroundColor Cyan
    
    # UltraVNC
    Write-Output " [INFO] Instalando UltraVNC..."
    switch ($choice) {
        "1" { winget install --id UltraVNC.UltraVNC }
        "2" { choco install ultravnc -y }
        "3" { 
            if (Test-Path "$serverPath\ultravnc_installer.exe") {
                Start-Process -FilePath "$serverPath\ultravnc_installer.exe" -Wait
            } else {
                Write-Output " [ERRO] Instalador UltraVNC nao encontrado no servidor local."
            }
        }
    }

    # Fusion
    Write-Output " [INFO] Instalando Fusion..."
    switch ($choice) {
        "1" { winget install --id Fusion.Fusion }
        "2" { Write-Output " [INFO] Fusion nao disponivel via Chocolatey. Use outro metodo." }
        "3" { 
            if (Test-Path "$serverPath\fusion_installer.exe") {
                Start-Process -FilePath "$serverPath\fusion_installer.exe" -Wait
            } else {
                Write-Output " [ERRO] Instalador Fusion nao encontrado no servidor local."
            }
        }
    }

    Write-Host " [SUCESSO] Instalacao de programas concluida." -ForegroundColor Green
    Pause
}

function Enable-RemoteAssistance {
    Write-Output " [INFO] Habilitando a Assistencia Remota..."

    # Verificar se o script esta sendo executado como administrador
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        Write-Host " [ALERTA] Este script precisa ser executado como Administrador para modificar o registro." -ForegroundColor Yellow
        
        # Oferecer opcoes alternativas ao usuario
        Write-Host "`nEscolha uma opcao:" -ForegroundColor Cyan
        Write-Host "1. Tentar executar comandos com privilegios elevados (recomendado)" -ForegroundColor Cyan
        Write-Host "2. Abrir configuracoes manuais da Assistencia Remota" -ForegroundColor Cyan
        $option = Read-Host "Opcao"
        
        if ($option -eq "1") {
            try {
                # Criar um script temporario para executar os comandos necessarios
                $tempScript = [System.IO.Path]::GetTempFileName() + ".ps1"
                $commands = @'
# Habilitar a Area de Trabalho Remota (Terminal Server)
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0

# Habilitar a Assistencia Remota
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fAllowToGetHelp" -Value 1

# Remover politica que trava a interface (se existir)
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -Name "fAllowToGetHelp" -ErrorAction SilentlyContinue

# Habilitar a Assistencia Remota nas Propriedades do Sistema
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "fAllowToGetHelp" -Value 1
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance" -Name "fAllowToGetHelp" -Value 1

# Configurar o Firewall para permitir conexoes de Assistencia Remota
Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue
Enable-NetFirewallRule -DisplayGroup "Área de Trabalho Remota" -ErrorAction SilentlyContinue
Enable-NetFirewallRule -DisplayGroup "Remote Assistance" -ErrorAction SilentlyContinue
Enable-NetFirewallRule -DisplayGroup "Assistencia Remota" -ErrorAction SilentlyContinue

# Habilitar e iniciar os servicos necessarios
$services = @("TermService", "SessionEnv", "UmRdpService", "RemoteRegistry")
foreach ($serviceName in $services) {
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if ($service) {
        if ($service.StartType -eq "Disabled") {
            Set-Service -Name $serviceName -StartupType Automatic
        }
        if ($service.Status -ne "Running") {
            Start-Service -Name $serviceName
        }
    }
}

Write-Host " [SUCESSO] Assistencia Remota habilitada com sucesso!" -ForegroundColor Green
Pause
'@
                Set-Content -Path $tempScript -Value $commands
                
                # Executar o script temporario como administrador usando runas
                Write-Host " [INFO] Tentando executar comandos com privilegios elevados..." -ForegroundColor Cyan
                Write-Host " [INFO] Se uma janela de confirmacao aparecer, clique em 'Sim' para continuar." -ForegroundColor Cyan
                Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tempScript`"" -Verb RunAs -Wait
                
                # Limpar o script temporario
                Remove-Item -Path $tempScript -Force -ErrorAction SilentlyContinue
                
                # Verificar se a configuracao foi bem-sucedida
                Test-RemoteAssistance
                return
            } catch {
                Write-Host " [ERRO] Nao foi possivel executar comandos com privilegios elevados: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host " [INFO] Tentando metodo alternativo..." -ForegroundColor Cyan
            }
        }
        
        # Metodo alternativo: Usar o comando system para abrir as propriedades do sistema na guia Remoto
        try {
            Write-Host " [INFO] Abrindo configuracoes de Assistencia Remota via interface grafica..." -ForegroundColor Cyan
            Start-Process SystemPropertiesRemote.exe
            
            Write-Host " [ALERTA] Uma janela de configuracao foi aberta. Por favor, siga estas instrucoes:" -ForegroundColor Yellow
            Write-Host "1. Na guia 'Remoto', marque a opcao 'Permitir conexoes de Assistencia Remota para este computador'" -ForegroundColor Yellow
            Write-Host "2. Marque tambem a opcao 'Permitir conexoes remotas para este computador'" -ForegroundColor Yellow
            Write-Host "3. Clique em 'OK' para salvar as configuracoes" -ForegroundColor Yellow
            
            # Aguardar interacao do usuario
            $confirmation = Read-Host "Voce concluiu a configuracao? (S/N)"
            if ($confirmation -eq 'S' -or $confirmation -eq 's') {
                Write-Host " [SUCESSO] Configuracao manual da Assistencia Remota concluida." -ForegroundColor Green
            } else {
                Write-Host " [ALERTA] A configuracao manual da Assistencia Remota nao foi concluida." -ForegroundColor Yellow
            }
            return
        } catch {
            Write-Host " [ERRO] Nao foi possivel abrir as configuracoes do sistema: $($_.Exception.Message)" -ForegroundColor Red
            return
        }
    }

    try {
        # Metodo 1: Habilitar a Assistencia Remota atraves do registro
        Write-Output " [INFO] Metodo 1: Configurando chaves de registro..."
        
        # Habilitar a Area de Trabalho Remota (Terminal Server)
        Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0 -ErrorAction SilentlyContinue
        
        # Habilitar a Assistencia Remota
        Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fAllowToGetHelp" -Value 1 -ErrorAction SilentlyContinue
        
        # Remover politica que trava a interface (se existir)
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -Name "fAllowToGetHelp" -ErrorAction SilentlyContinue
        
        # Habilitar a Assistencia Remota nas Propriedades do Sistema
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "fAllowToGetHelp" -Value 1 -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance" -Name "fAllowToGetHelp" -Value 1 -ErrorAction SilentlyContinue

        # Metodo 2: Configurar o Firewall para permitir conexoes de Assistencia Remota
        Write-Output " [INFO] Metodo 2: Configurando regras de Firewall..."
        Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue
        Enable-NetFirewallRule -DisplayGroup "Área de Trabalho Remota" -ErrorAction SilentlyContinue
        Enable-NetFirewallRule -DisplayGroup "Remote Assistance" -ErrorAction SilentlyContinue
        Enable-NetFirewallRule -DisplayGroup "Assistencia Remota" -ErrorAction SilentlyContinue
        
        # Metodo 3: Habilitar e iniciar os servicos necessarios
        Write-Output " [INFO] Metodo 3: Habilitando servicos necessarios..."
        $services = @("TermService", "SessionEnv", "UmRdpService", "RemoteRegistry")
        
        foreach ($serviceName in $services) {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if ($service) {
                if ($service.StartType -eq "Disabled") {
                    Set-Service -Name $serviceName -StartupType Automatic -ErrorAction SilentlyContinue
                    Write-Host " [INFO] Servico $serviceName configurado para iniciar automaticamente."
                }
                
                if ($service.Status -ne "Running") {
                    Start-Service -Name $serviceName -ErrorAction SilentlyContinue
                    Write-Host " [SUCESSO] Servico $serviceName iniciado."
                } else {
                    Write-Host " [INFO] Servico $serviceName ja esta em execucao."
                }
            }
        }
        
        Write-Host " [SUCESSO] Assistencia Remota habilitada com multiplos metodos."
    } catch {
        Write-Host " [ERRO] Nao foi possivel habilitar a Assistencia Remota via PowerShell: $($_.Exception.Message)"
        Write-Host " [INFO] Tentando metodo alternativo via configuracao do sistema..."
        try {
            # Metodo 4: Usar o comando system para abrir as propriedades do sistema na guia Remoto
            Write-Host " [INFO] Abrindo configuracoes de Assistencia Remota via interface grafica..."
            Start-Process SystemPropertiesRemote.exe
            
            Write-Host " [ALERTA] Uma janela de configuracao foi aberta. Por favor, siga estas instrucoes:" -ForegroundColor Yellow
            Write-Host "1. Na guia 'Remoto', marque a opcao 'Permitir conexoes de Assistencia Remota para este computador'" -ForegroundColor Yellow
            Write-Host "2. Marque tambem a opcao 'Permitir conexoes remotas para este computador'" -ForegroundColor Yellow
            Write-Host "3. Clique em 'OK' para salvar as configuracoes" -ForegroundColor Yellow
            
            # Aguardar interacao do usuario
            $confirmation = Read-Host "Voce concluiu a configuracao? (S/N)"
            if ($confirmation -eq 'S' -or $confirmation -eq 's') {
                Write-Host " [SUCESSO] Configuracao manual da Assistencia Remota concluida." -ForegroundColor Green
            } else {
                Write-Host " [ALERTA] A configuracao manual da Assistencia Remota nao foi concluida." -ForegroundColor Yellow
            }
        } catch {
            Write-Host " [ERRO] Nao foi possivel abrir as configuracoes do sistema: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

function Test-RemoteAssistance {
    Write-Output " [INFO] Testando configuracao da Assistencia Remota..."
    
    # Verificar se o script esta sendo executado como administrador
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        Write-Host " [ALERTA] Este script precisa ser executado como Administrador para verificar todas as configuracoes." -ForegroundColor Yellow
Write-Host " [INFO] Algumas verificacoes podem falhar ou retornar resultados incompletos." -ForegroundColor Yellow
    }
    
    try {
        # Verificar chaves de registro
        $terminalServerDeny = Get-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -ErrorAction SilentlyContinue
        $terminalServerAllow = Get-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fAllowToGetHelp" -ErrorAction SilentlyContinue
        $winlogonAllow = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "fAllowToGetHelp" -ErrorAction SilentlyContinue
        
        # Verificar servicos
        $termService = Get-Service -Name "TermService" -ErrorAction SilentlyContinue
        
        # Verificar regras de firewall (Suporta PT-BR e EN-US)
        $firewallRules = Get-NetFirewallRule -DisplayGroup "Remote Desktop", "Área de Trabalho Remota" -ErrorAction SilentlyContinue | Where-Object { $_.Enabled -eq $true }
        
        # Exibir resultados
        Write-Host "`nResultados do diagnostico da Assistencia Remota:" -ForegroundColor Cyan
        Write-Host "----------------------------------------" -ForegroundColor Cyan
        
        Write-Host "Configuracoes de Registro:" -ForegroundColor White
Write-Host "- Conexoes Terminal Server negadas: $(if ($terminalServerDeny.fDenyTSConnections -eq 0) { 'Nao (Correto)' } else { 'Sim (Problema)' })" -ForegroundColor $(if ($terminalServerDeny.fDenyTSConnections -eq 0) { 'Green' } else { 'Red' })
Write-Host "- Assistencia Remota permitida (Terminal Server): $(if ($terminalServerAllow.fAllowToGetHelp -eq 1) { 'Sim (Correto)' } else { 'Nao (Problema)' })" -ForegroundColor $(if ($terminalServerAllow.fAllowToGetHelp -eq 1) { 'Green' } else { 'Red' })
Write-Host "- Assistencia Remota permitida (Winlogon): $(if ($winlogonAllow.fAllowToGetHelp -eq 1) { 'Sim (Correto)' } else { 'Nao (Problema)' })" -ForegroundColor $(if ($winlogonAllow.fAllowToGetHelp -eq 1) { 'Green' } else { 'Red' })
        
        Write-Host "`nServicos:" -ForegroundColor White
Write-Host "- Servico Terminal Server: $(if ($termService.Status -eq 'Running') { 'Em execucao (Correto)' } else { 'Parado (Problema)' })" -ForegroundColor $(if ($termService.Status -eq 'Running') { 'Green' } else { 'Red' })
        
        Write-Host "`nFirewall:" -ForegroundColor White
        Write-Host "- Regras de Area de Trabalho Remota: $(if ($firewallRules -ne $null) { 'Habilitadas (Correto)' } else { 'Desabilitadas (Problema)' })" -ForegroundColor $(if ($firewallRules -ne $null) { 'Green' } else { 'Red' })
        
        # Verificar se ha problemas
        $hasIssues = ($terminalServerDeny.fDenyTSConnections -ne 0) -or 
                    ($terminalServerAllow.fAllowToGetHelp -ne 1) -or 
                    ($winlogonAllow.fAllowToGetHelp -ne 1) -or 
                    ($termService.Status -ne 'Running') -or 
                    ($firewallRules -eq $null)
        
        if ($hasIssues) {
            Write-Host "`n[ALERTA] Foram encontrados problemas na configuracao da Assistencia Remota." -ForegroundColor Yellow
Write-Host "Execute a funcao Enable-RemoteAssistance novamente para corrigir os problemas." -ForegroundColor Yellow
            
            if (-not $isAdmin) {
                Write-Host "`n[IMPORTANTE] Execute o script como Administrador para corrigir automaticamente os problemas." -ForegroundColor Yellow
                Write-Host " [DICA] Alternativamente, voce pode usar a opcao 'Habilitar Assistencia Remota' que abrira a interface grafica para configuracao manual." -ForegroundColor Yellow
            }
        } else {
            Write-Host "`n[SUCESSO] A Assistencia Remota esta configurada corretamente." -ForegroundColor Green
        }
    } catch {
        Write-Host " [ERRO] Ocorreu um erro ao testar a configuracao da Assistencia Remota: $($_.Exception.Message)" -ForegroundColor Red
        
        if (-not $isAdmin) {
            Write-Host " [DICA] Execute o script como Administrador para ter acesso completo as configuracoes do sistema." -ForegroundColor Yellow
        }
    }
}

function Enable-RemoteDesktop {
    Write-Output " [INFO] Habilitando a Area de Trabalho Remota..."

    try {
        # Habilitar a Area de Trabalho Remota
        Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0
        Write-Host " [SUCESSO] Area de Trabalho Remota habilitada."
    } catch {
        Write-Host " [ERRO] Nao foi possivel habilitar a Area de Trabalho Remota."
    }
}

function Set-ComputerName {
    # Solicita o novo nome para o computador
    $newName = Read-Host "Digite o novo nome para o computador"
    
    # Aplica o novo nome ao computador
    try {
        Rename-Computer -NewName $newName -Force -Restart
        Write-Host " [SUCESSO] Nome do computador alterado para: $newName. O sistema sera reiniciado para aplicar a alteracao."
    } catch {
        Write-Host " [ERRO] Nao foi possivel alterar o nome do computador."
    }
}

function Set-DomainName {
    # Solicita o dominio e o nome de usuario
    $domainName = Read-Host "Digite o nome do dominio (ex: dominio.com)"
    $username = Read-Host "Digite o nome de usuario com permissoes para adicionar ao dominio"
    $password = Read-Host "Digite a senha para o usuario do dominio" -AsSecureString

    # Verifica se o computador ja esta no dominio
    $currentDomain = (Get-WmiObject -Class Win32_ComputerSystem).Domain
    if ($currentDomain -ne $domainName) {
        Write-Host " [INFO] O computador nao esta no dominio $domainName. Tentando adicionar..."
        try {
            Add-Computer -DomainName $domainName -Credential (New-Object System.Management.Automation.PSCredential($username, $password)) -Force -Restart
            Write-Host " [SUCESSO] Computador adicionado ao dominio $domainName. O sistema sera reiniciado para aplicar a alteracao."
        } catch {
            Write-Host " [ERRO] Nao foi possivel adicionar o computador ao dominio."
        }
    } else {
        Write-Host " [INFO] O computador ja esta no dominio $domainName."
    }
}

# Funcao para criar a conta "admin" no grupo Administradores sem senha
function Create-AdminAccount {
    Write-Host " [INFO] Criando conta de usuario 'admin'..."

    try {
        if (-not (Get-LocalUser -Name "admin" -ErrorAction SilentlyContinue)) {
            New-LocalUser -Name "admin" -NoPassword -Description "Conta de administrador criada via script" -PasswordNeverExpires $true
            Write-Host " [SUCESSO] Conta 'admin' criada com sucesso." -ForegroundColor Green
        } else {
            Write-Host " [INFO] A conta 'admin' ja existe no sistema." -ForegroundColor Yellow
        }

        Set-LocalUser -Name "admin" -PasswordNeverExpires $true -ErrorAction SilentlyContinue

        # Adicionar ao grupo Administradores
        $groupName = (Get-LocalGroup | Where-Object { $_.SID -match "S-1-5-32-544" }).Name
        if (-not $groupName) { $groupName = "Administradores" }
        
        $groupMembers = Get-LocalGroupMember -Group $groupName | Select-Object -ExpandProperty Name
        if ($groupMembers -notcontains "$env:COMPUTERNAME\admin" -and $groupMembers -notcontains "admin") {
            Add-LocalGroupMember -Group $groupName -Member "admin"
            Write-Host " [SUCESSO] Conta 'admin' adicionada ao grupo '$groupName'." -ForegroundColor Green
        } else {
            Write-Host " [INFO] A conta 'admin' ja pertence ao grupo '$groupName'." -ForegroundColor Yellow
        }

        # Remover do grupo Usuarios (adicionado automaticamente pelo Windows ao criar o usuario)
        $usersGroup = (Get-LocalGroup | Where-Object { $_.SID -match "S-1-5-32-545" }).Name
        if (-not $usersGroup) { $usersGroup = "Usuarios" }
        $usersMembers = Get-LocalGroupMember -Group $usersGroup -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
        if ($usersMembers -contains "$env:COMPUTERNAME\admin" -or $usersMembers -contains "admin") {
            Remove-LocalGroupMember -Group $usersGroup -Member "admin" -ErrorAction SilentlyContinue
            Write-Host " [INFO] Conta 'admin' removida do grupo '$usersGroup'." -ForegroundColor Yellow
        }
    } catch {
        Write-Host " [ERRO] Falha ao criar conta 'admin': $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Encripta senha no formato VNC (DES com bits invertidos por byte)
function ConvertTo-VNCPassword ([string]$Password) {
    $pw  = $Password.PadRight(8, "`0").Substring(0, 8)
    $key = [byte[]]::new(8)
    for ($i = 0; $i -lt 8; $i++) {
        $b = [byte][char]$pw[$i]; $rb = 0
        for ($j = 0; $j -lt 8; $j++) { $rb = ($rb -shl 1) -bor ($b -band 1); $b = $b -shr 1 }
        $key[$i] = [byte]$rb
    }
    $des = [System.Security.Cryptography.DES]::Create()
    $des.Key = $key
    $des.IV  = [byte[]]::new(8)
    $des.Mode    = [System.Security.Cryptography.CipherMode]::ECB
    $des.Padding = [System.Security.Cryptography.PaddingMode]::None
    $cipher = $des.CreateEncryptor().TransformFinalBlock([byte[]]::new(8), 0, 8)
    return ($cipher | ForEach-Object { $_.ToString("x2") }) -join ""
}

# Funcao de padronizacao automatica
function Start-AutoPadronizacao {
    Clear-Host
    Write-Host ""
    Write-Host "  ==========================================================" -ForegroundColor Cyan
    Write-Host "               PADRONIZACAO AUTOMATICA" -ForegroundColor Yellow
    Write-Host "  ==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Este processo ira configurar automaticamente:" -ForegroundColor White
    Write-Host "   1. Fuso horario (Manaus - UTC-04:00)" -ForegroundColor DarkCyan
    Write-Host "   2. Assistencia Remota" -ForegroundColor DarkCyan
    Write-Host "   3. Area de Trabalho Remota (RDP)" -ForegroundColor DarkCyan
    Write-Host "   4. Nome do computador" -ForegroundColor DarkCyan
    Write-Host "   5. Ingresso no dominio" -ForegroundColor DarkCyan
    Write-Host "   6. Conta de administrador local" -ForegroundColor DarkCyan
    Write-Host "   7. Instalacao de programas padrao (Chocolatey)" -ForegroundColor DarkCyan
    Write-Host ""
    Write-Host "  Etapas que exigirem reinicializacao serao acumuladas" -ForegroundColor DarkGray
    Write-Host "  e voce escolhera reiniciar ao final." -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  ==========================================================" -ForegroundColor Cyan
    Write-Host ""

    $needsRestart = $false

    # Variaveis de rastreamento para o resumo visual final
    $stFuso      = $null
    $stAssist    = $null
    $stRdp       = $null
    $stNome      = $null; $stNomeVal = ""
    $stDominio   = $null; $stDominioVal = ""
    $stAdmin     = $null; $stAdminMsg = ""
    $progsOk     = @()
    $progsFail   = @()
    $stChoco     = $null

    # ----------------------------------------------------------
    # ETAPA 1: Fuso horario (Manaus - automatico, sem interacao)
    # ----------------------------------------------------------
    Write-Host "  [1/7] Configurando fuso horario para Manaus..." -ForegroundColor Cyan
    try {
        Set-TimeZone -Id "SA Western Standard Time" -ErrorAction Stop
        $stFuso = "OK"
        Write-Host "  [SUCESSO] Fuso horario definido: Manaus (UTC-04:00)" -ForegroundColor Green
    } catch {
        $stFuso = "ERRO"
        Write-Host "  [ERRO] Nao foi possivel definir o fuso horario: $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host ""

    # ----------------------------------------------------------
    # ETAPA 2: Assistencia Remota
    # ----------------------------------------------------------
    Write-Host "  [2/7] Habilitando Assistencia Remota..." -ForegroundColor Cyan
    try {
        Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0 -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fAllowToGetHelp" -Value 1 -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -Name "fAllowToGetHelp" -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "fAllowToGetHelp" -Value 1 -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance" -Name "fAllowToGetHelp" -Value 1 -ErrorAction SilentlyContinue
        Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue
        Enable-NetFirewallRule -DisplayGroup "Área de Trabalho Remota" -ErrorAction SilentlyContinue
        Enable-NetFirewallRule -DisplayGroup "Remote Assistance" -ErrorAction SilentlyContinue
        Enable-NetFirewallRule -DisplayGroup "Assistencia Remota" -ErrorAction SilentlyContinue
        $svcList = @("TermService", "SessionEnv", "UmRdpService", "RemoteRegistry")
        foreach ($svcName in $svcList) {
            $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
            if ($svc) {
                if ($svc.StartType -eq "Disabled") { Set-Service -Name $svcName -StartupType Automatic -ErrorAction SilentlyContinue }
                if ($svc.Status -ne "Running")      { Start-Service -Name $svcName -ErrorAction SilentlyContinue }
            }
        }
        $stAssist = "OK"
        Write-Host "  [SUCESSO] Assistencia Remota habilitada." -ForegroundColor Green
    } catch {
        $stAssist = "ERRO"
        Write-Host "  [ERRO] $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host ""

    # ----------------------------------------------------------
    # ETAPA 3: Area de Trabalho Remota (RDP)
    # ----------------------------------------------------------
    Write-Host "  [3/7] Habilitando Area de Trabalho Remota (RDP)..." -ForegroundColor Cyan
    try {
        Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0 -ErrorAction Stop
        $stRdp = "OK"
        Write-Host "  [SUCESSO] Area de Trabalho Remota habilitada." -ForegroundColor Green
    } catch {
        $stRdp = "ERRO"
        Write-Host "  [ERRO] $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host ""

    # ----------------------------------------------------------
    # ETAPA 4: Nome do computador
    # ----------------------------------------------------------
    Write-Host "  [4/7] Alteracao do nome do computador" -ForegroundColor Cyan
    Write-Host "  Nome atual: $env:COMPUTERNAME" -ForegroundColor White
    $newName = Read-Host "  Novo nome (pressione Enter para pular)"
    if ($newName.Trim() -ne "") {
        try {
            Rename-Computer -NewName $newName.Trim() -Force -ErrorAction Stop
            $needsRestart = $true
            $stNome    = "OK"
            $stNomeVal = $newName.Trim()
            Write-Host "  [SUCESSO] Nome alterado para '$($newName.Trim())'. Reinicializacao necessaria para aplicar." -ForegroundColor Green
        } catch {
            $stNome = "ERRO"
            Write-Host "  [ERRO] $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        $stNome = "IGNORADO"
        Write-Host "  [INFO] Etapa ignorada." -ForegroundColor DarkGray
    }
    Write-Host ""

    # ----------------------------------------------------------
    # ETAPA 5: Ingresso no dominio
    # ----------------------------------------------------------
    Write-Host "  [5/7] Ingresso no dominio" -ForegroundColor Cyan
    $currentDomain = (Get-WmiObject -Class Win32_ComputerSystem -ErrorAction SilentlyContinue).Domain
    Write-Host "  Dominio atual: $currentDomain" -ForegroundColor White
    $domainName = Read-Host "  Nome do dominio (pressione Enter para pular)"
    if ($domainName.Trim() -ne "") {
        $domUser = Read-Host "  Usuario com permissao no dominio"
        $domPass = Read-Host "  Senha" -AsSecureString
        try {
            $cred = New-Object System.Management.Automation.PSCredential($domUser, $domPass)
            Add-Computer -DomainName $domainName.Trim() -Credential $cred -Force -ErrorAction Stop
            $needsRestart   = $true
            $stDominio      = "OK"
            $stDominioVal   = $domainName.Trim()
            Write-Host "  [SUCESSO] Computador adicionado ao dominio '$($domainName.Trim())'. Reinicializacao necessaria para aplicar." -ForegroundColor Green
        } catch {
            $stDominio = "ERRO"
            Write-Host "  [ERRO] $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        $stDominio = "IGNORADO"
        Write-Host "  [INFO] Etapa ignorada." -ForegroundColor DarkGray
    }
    Write-Host ""

    # ----------------------------------------------------------
    # ETAPA 6: Conta de administrador local
    # ----------------------------------------------------------
    Write-Host "  [6/7] Criando conta de administrador local..." -ForegroundColor Cyan
    try {
        if (-not (Get-LocalUser -Name "admin" -ErrorAction SilentlyContinue)) {
            try {
                New-LocalUser -Name "admin" -NoPassword -Description "Conta de administrador criada via script" -ErrorAction Stop -PasswordNeverExpires $true
            } catch {
                $netOut = net user admin "" /add /y 2>&1
                if ($LASTEXITCODE -ne 0) { throw "Falha ao criar conta admin: $netOut" }
            }
            Write-Host "  [SUCESSO] Conta 'admin' criada." -ForegroundColor Green
            $stAdminMsg = "Conta criada"
        } else {
            Write-Host "  [INFO] Conta 'admin' ja existe." -ForegroundColor DarkGray
            $stAdminMsg = "Conta ja existia"
        }
        Set-LocalUser -Name "admin" -PasswordNeverExpires $true -ErrorAction SilentlyContinue
        $groupName = (Get-LocalGroup | Where-Object { $_.SID -match "S-1-5-32-544" }).Name
        if (-not $groupName) { $groupName = "Administradores" }
        $members = Get-LocalGroupMember -Group $groupName | Select-Object -ExpandProperty Name
        if ($members -notcontains "$env:COMPUTERNAME\admin" -and $members -notcontains "admin") {
            Add-LocalGroupMember -Group $groupName -Member "admin" -ErrorAction Stop
            Write-Host "  [SUCESSO] Conta 'admin' adicionada ao grupo '$groupName'." -ForegroundColor Green
            $stAdminMsg += " | adicionada ao grupo '$groupName'"
        } else {
            Write-Host "  [INFO] Conta 'admin' ja pertence ao grupo '$groupName'." -ForegroundColor DarkGray
            $stAdminMsg += " | ja era membro do grupo '$groupName'"
        }

        # Remover do grupo Usuarios (adicionado automaticamente pelo Windows ao criar o usuario)
        $usersGroup = (Get-LocalGroup | Where-Object { $_.SID -match "S-1-5-32-545" }).Name
        if (-not $usersGroup) { $usersGroup = "Usuarios" }
        $usersMembers = Get-LocalGroupMember -Group $usersGroup -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
        if ($usersMembers -contains "$env:COMPUTERNAME\admin" -or $usersMembers -contains "admin") {
            Remove-LocalGroupMember -Group $usersGroup -Member "admin" -ErrorAction SilentlyContinue
            Write-Host "  [INFO] Conta 'admin' removida do grupo '$usersGroup'." -ForegroundColor DarkGray
        }
        $stAdmin = "OK"
    } catch {
        $stAdmin = "ERRO"
        Write-Host "  [ERRO] $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host ""

    # ----------------------------------------------------------
    # ETAPA 7: Instalacao de programas via Chocolatey
    # ----------------------------------------------------------
    Write-Host "  [7/7] Instalando programas padrao via Chocolatey..." -ForegroundColor Cyan

    $chocoInstalled = $false
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        $chocoInstalled = $true
        Write-Host "  [INFO] Chocolatey ja esta instalado." -ForegroundColor DarkGray
    } else {
        Write-Host "  [INFO] Chocolatey nao encontrado. Instalando..." -ForegroundColor Yellow
        try {
            Set-ExecutionPolicy Bypass -Scope Process -Force
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

            # Recarrega o PATH para reconhecer o choco recem instalado
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                        [System.Environment]::GetEnvironmentVariable("Path", "User")

            if (Get-Command choco -ErrorAction SilentlyContinue) {
                $chocoInstalled = $true
                Write-Host "  [SUCESSO] Chocolatey instalado com sucesso." -ForegroundColor Green
            } else {
                throw "Chocolatey instalado mas nao reconhecido no PATH."
            }
        } catch {
            $stChoco = "ERRO"
            Write-Host ""
            Write-Host "  [ERRO] Falha ao instalar o Chocolatey: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host ""
            Write-Host "  [COMO CORRIGIR]" -ForegroundColor Yellow
            Write-Host "  1. Abra o PowerShell como Administrador" -ForegroundColor Yellow
            Write-Host "  2. Execute: Set-ExecutionPolicy Bypass -Scope Process -Force" -ForegroundColor Yellow
            Write-Host "  3. Execute: [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072" -ForegroundColor Yellow
            Write-Host "  4. Execute: iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))" -ForegroundColor Yellow
            Write-Host "  5. Feche e reabra o PowerShell, depois tente a padronizacao novamente." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "  [INFO] Instalacao de programas ignorada devido a falha no Chocolatey." -ForegroundColor DarkGray
        }
    }

    if ($chocoInstalled) {
        $stChoco = "OK"

        $autoPrograms = @(
            @{ ChocoId = "Temurin8jre";       Name = "Java (JRE)" },
            @{ ChocoId = "winrar";            Name = "WinRAR" },
            @{ ChocoId = "vlc";               Name = "VLC" },
            @{ ChocoId = "FoxitReader";       Name = "Foxit Reader" },
            @{ ChocoId = "pdf24";             Name = "PDF24" },
            @{ ChocoId = "libreoffice-still"; Name = "LibreOffice" },
            @{ ChocoId = "GoogleChrome";      Name = "Google Chrome"; ExtraArgs = "--ignore-checksums" },
            @{ ChocoId = "Firefox";           Name = "Mozilla Firefox" }
        )

        Write-Host "  Instalando $($autoPrograms.Count) programas sequencialmente..." -ForegroundColor DarkGray
        Write-Host ""

        $globalStart = Get-Date
        $progIdx     = 0

        foreach ($prog in $autoPrograms) {
            $progIdx++
            $progStart = Get-Date

            Write-Progress -Activity "Instalando programas via Chocolatey" `
                           -Status "[$progIdx/$($autoPrograms.Count)] $($prog.Name)" `
                           -PercentComplete (($progIdx - 1) / $autoPrograms.Count * 100)

            Write-Host "  [$progIdx/$($autoPrograms.Count)] $($prog.Name)" -ForegroundColor Cyan

            $chocoArgs = @($prog.ChocoId, '-y', '--no-progress')
            if ($prog.ContainsKey('ExtraArgs') -and $prog.ExtraArgs) {
                $chocoArgs += $prog.ExtraArgs.Split(' ')
            }
            & choco install @chocoArgs
            $exitCode = $LASTEXITCODE

            $elapsed = [math]::Round(((Get-Date) - $progStart).TotalSeconds)
            $timeStr = if ($elapsed -ge 60) { "$([math]::Floor($elapsed/60))m$($elapsed%60)s" } else { "${elapsed}s" }

            if ($exitCode -eq 0) {
                $progsOk += $prog.Name
                Write-Host "  [OK]   $($prog.Name.PadRight(18)) concluido em $timeStr" -ForegroundColor Green
            } else {
                $progsFail += $prog.Name
                Write-Host "  [ERRO] $($prog.Name.PadRight(18)) falhou em $timeStr (codigo: $exitCode)" -ForegroundColor Red
            }
            Write-Host ""
        }

        Write-Progress -Activity "Instalando programas via Chocolatey" -Completed

        $total = [math]::Round(((Get-Date) - $globalStart).TotalSeconds)
        Write-Host "  Instalacoes finalizadas em $([math]::Floor($total/60))m$($total%60)s | $($progsOk.Count) OK / $($progsFail.Count) falha(s)" -ForegroundColor DarkGray
    }
    Write-Host ""

    # ----------------------------------------------------------
    # ULTRAVNC: Instalacao interativa (por ultimo)
    # ----------------------------------------------------------
    Write-Host "  [ULTRAVNC] Abrindo instalador do UltraVNC..." -ForegroundColor Cyan
    Write-Host "  [INFO] O instalador sera aberto. Configure porta, senha e opcoes desejadas," -ForegroundColor Yellow
    Write-Host "  [INFO] depois clique em Instalar. O script aguarda a conclusao." -ForegroundColor Yellow
    Write-Host ""

    $vncStart = Get-Date
    choco install ultravnc --override-arguments --install-arguments="/SP- /NORESTART" -y
    $vncExit    = $LASTEXITCODE
    $vncElapsed = [math]::Round(((Get-Date) - $vncStart).TotalSeconds)
    $vncTimeStr = if ($vncElapsed -ge 60) { "$([math]::Floor($vncElapsed/60))m$($vncElapsed%60)s" } else { "${vncElapsed}s" }

    if ($vncExit -eq 0) {
        $progsOk += "UltraVNC"
        Write-Host "  [OK]   UltraVNC instalado em $vncTimeStr" -ForegroundColor Green
    } else {
        $progsFail += "UltraVNC"
        Write-Host "  [ERRO] UltraVNC falhou em $vncTimeStr (codigo: $vncExit)" -ForegroundColor Red
    }
    Write-Host ""

    # ----------------------------------------------------------
    # AVISO: Etapas manuais restantes
    # ----------------------------------------------------------
    Write-Host "  ==========================================================" -ForegroundColor Yellow
    Write-Host "              ATENCAO — ETAPAS MANUAIS RESTANTES" -ForegroundColor Yellow
    Write-Host "  ==========================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  As etapas abaixo NAO foram automatizadas e devem ser" -ForegroundColor White
    Write-Host "  realizadas manualmente antes de entregar a maquina:" -ForegroundColor White
    Write-Host ""
    Write-Host "   [1] CERTIFICADO FORTINET" -ForegroundColor Cyan
    Write-Host "       Importar o certificado Fortinet nos certificados" -ForegroundColor White
    Write-Host "       confiaveis da maquina (certmgr.msc)." -ForegroundColor White
    Write-Host ""
    Write-Host "   [2] KASPERSKY" -ForegroundColor Cyan
    Write-Host "       Instalar e ativar o Kaspersky manualmente." -ForegroundColor White
    Write-Host "       Instalador disponivel em:" -ForegroundColor White
    Write-Host "       \\balbina\suporte\Kasper ok\" -ForegroundColor DarkCyan
    Write-Host ""
    Write-Host "  ==========================================================" -ForegroundColor Yellow
    Write-Host ""

    # ----------------------------------------------------------
    # RESUMO VISUAL FINAL
    # ----------------------------------------------------------
    Write-Host "  ==========================================================" -ForegroundColor Cyan
    Write-Host "                 RESUMO DA PADRONIZACAO" -ForegroundColor Yellow
    Write-Host "  ==========================================================" -ForegroundColor Cyan
    Write-Host ""

    # Pre-calcula detalhes das etapas opcionais
    $nomeDetalhe = switch ($stNome) {
        "OK"       { "Alterado para: $stNomeVal  (requer reinicio)" }
        "ERRO"     { "Falhou ao renomear" }
        "IGNORADO" { "" }
    }
    $dominioDetalhe = switch ($stDominio) {
        "OK"       { "Ingressou em: $stDominioVal  (requer reinicio)" }
        "ERRO"     { "Falhou ao ingressar no dominio" }
        "IGNORADO" { "" }
    }

    $linhas = @(
        @{ Label = "Fuso horario";       Status = $stFuso;    Detalhe = "Manaus (UTC-04:00)" },
        @{ Label = "Assistencia Remota"; Status = $stAssist;  Detalhe = "Habilitada (registro + firewall + servicos)" },
        @{ Label = "RDP";                Status = $stRdp;     Detalhe = "Habilitado" },
        @{ Label = "Nome do computador"; Status = $stNome;    Detalhe = $nomeDetalhe },
        @{ Label = "Dominio";            Status = $stDominio; Detalhe = $dominioDetalhe },
        @{ Label = "Conta admin";        Status = $stAdmin;   Detalhe = $stAdminMsg }
    )

    foreach ($linha in $linhas) {
        $pad = $linha.Label.PadRight(22)
        switch ($linha.Status) {
            "OK" {
                Write-Host "   " -NoNewline
                Write-Host "[OK]   " -ForegroundColor Green -NoNewline
                Write-Host "$pad" -NoNewline
                if ($linha.Detalhe) { Write-Host "-> $($linha.Detalhe)" -ForegroundColor White } else { Write-Host "" }
            }
            "ERRO" {
                Write-Host "   " -NoNewline
                Write-Host "[ERRO] " -ForegroundColor Red -NoNewline
                Write-Host "$pad" -NoNewline
                if ($linha.Detalhe) { Write-Host "-> $($linha.Detalhe)" -ForegroundColor Red } else { Write-Host "-> Falhou" -ForegroundColor Red }
            }
            "IGNORADO" {
                Write-Host "   " -NoNewline
                Write-Host "[ -- ] " -ForegroundColor DarkGray -NoNewline
                Write-Host "$pad" -NoNewline
                Write-Host "-> Ignorado pelo usuario" -ForegroundColor DarkGray
            }
        }
    }

    # Linha de programas (logica separada por ser mais complexa)
    $padProg = "Programas (choco)".PadRight(22)
    if ($stChoco -eq "ERRO") {
        Write-Host "   " -NoNewline
        Write-Host "[ERRO] " -ForegroundColor Red -NoNewline
        Write-Host "$padProg" -NoNewline
        Write-Host "-> Falha na instalacao do Chocolatey (veja instrucoes acima)" -ForegroundColor Red
    } elseif ($stChoco -eq "OK" -and $progsFail.Count -eq 0) {
        Write-Host "   " -NoNewline
        Write-Host "[OK]   " -ForegroundColor Green -NoNewline
        Write-Host "$padProg" -NoNewline
        Write-Host "-> $($progsOk.Count) de $($progsOk.Count) instalados com sucesso" -ForegroundColor White
    } elseif ($stChoco -eq "OK") {
        $totalProgs = $progsOk.Count + $progsFail.Count
        Write-Host "   " -NoNewline
        Write-Host "[ERRO] " -ForegroundColor Red -NoNewline
        Write-Host "$padProg" -NoNewline
        Write-Host "-> $($progsOk.Count)/$totalProgs OK | Falhas: $($progsFail -join ', ')" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "  ==========================================================" -ForegroundColor Cyan
    Write-Host ""

    if ($needsRestart) {
        Write-Host "  [AVISO] Algumas alteracoes exigem reinicializacao para entrar em vigor." -ForegroundColor Yellow
        Write-Host ""
        $restart = Read-Host "  Deseja reiniciar o computador agora? (S/N)"
        if ($restart -eq 'S' -or $restart -eq 's') {
            Write-Host "  Reiniciando em 5 segundos..." -ForegroundColor Cyan
            Start-Sleep -Seconds 5
            Restart-Computer -Force
        } else {
            Write-Host "  [INFO] Reinicie o computador manualmente para aplicar todas as alteracoes." -ForegroundColor Yellow
        }
    }
}

# GUI de padronizacao
function Show-PadronizacaoGUI {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $corFundo    = [System.Drawing.Color]::FromArgb(28, 28, 28)
    $corPainel   = [System.Drawing.Color]::FromArgb(45, 45, 45)
    $corTexto    = [System.Drawing.Color]::White
    $corDestaque = [System.Drawing.Color]::FromArgb(0, 170, 230)
    $corAmarelo  = [System.Drawing.Color]::FromArgb(255, 210, 0)
    $corBotao    = [System.Drawing.Color]::FromArgb(0, 110, 170)
    $corOk       = [System.Drawing.Color]::LimeGreen
    $corErro     = [System.Drawing.Color]::OrangeRed
    $corInfo     = [System.Drawing.Color]::DeepSkyBlue
    $corAviso    = [System.Drawing.Color]::FromArgb(255, 210, 0)
    $corBtnTool  = [System.Drawing.Color]::FromArgb(55, 55, 70)

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "SEMSA Suporte"
    $form.Size = New-Object System.Drawing.Size(930, 760)
    $form.StartPosition = "CenterScreen"
    $form.BackColor = $corFundo
    $form.ForeColor = $corTexto
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false

    $lblTitulo = New-Object System.Windows.Forms.Label
    $lblTitulo.Text = "SEMSA SUPORTE"
    $lblTitulo.Font = New-Object System.Drawing.Font("Consolas", 13, [System.Drawing.FontStyle]::Bold)
    $lblTitulo.ForeColor = $corDestaque
    $lblTitulo.AutoSize = $true
    $lblTitulo.Location = New-Object System.Drawing.Point(15, 10)
    $form.Controls.Add($lblTitulo)

    # ----------------------------------------------------------
    # PAINEL FERRAMENTAS (esquerdo)
    # ----------------------------------------------------------
    $panelTools = New-Object System.Windows.Forms.Panel
    $panelTools.Location = New-Object System.Drawing.Point(10, 38)
    $panelTools.Size = New-Object System.Drawing.Size(190, 362)
    $panelTools.BackColor = $corPainel
    $form.Controls.Add($panelTools)

    $mkHeader = {
        param([string]$txt, [int]$y)
        $l = New-Object System.Windows.Forms.Label
        $l.Text = "  $txt"
        $l.Font = New-Object System.Drawing.Font("Consolas", 7, [System.Drawing.FontStyle]::Bold)
        $l.ForeColor = $corDestaque
        $l.Size = New-Object System.Drawing.Size(190, 14)
        $l.Location = New-Object System.Drawing.Point(0, $y)
        $panelTools.Controls.Add($l)
    }

    $mkBtn = {
        param([string]$txt, [int]$y)
        $b = New-Object System.Windows.Forms.Button
        $b.Text = $txt
        $b.Font = New-Object System.Drawing.Font("Consolas", 8)
        $b.BackColor = $corBtnTool
        $b.ForeColor = $corTexto
        $b.FlatStyle = "Flat"
        $b.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(70, 70, 90)
        $b.FlatAppearance.BorderSize = 1
        $b.Size = New-Object System.Drawing.Size(170, 22)
        $b.Location = New-Object System.Drawing.Point(10, $y)
        $panelTools.Controls.Add($b)
        return $b
    }

    & $mkHeader "INFORMACOES" 5
    $btnInfoPC   = & $mkBtn "Info do PC"         22
    $btnChave    = & $mkBtn "Chave Windows"       47
    $btnAtivar   = & $mkBtn "Ativar Win/Office"   72

    & $mkHeader "CONFIGURAR" 100
    $btnAssist   = & $mkBtn "Assist. Remota"      117
    $btnTestar   = & $mkBtn "Testar Assist."      142
    $btnRDP      = & $mkBtn "Habilitar RDP"       167
    $btnFuso     = & $mkBtn "Fuso Horario"        192
    $btnAdmin    = & $mkBtn "Conta Admin"         217

    & $mkHeader "COMPUTADOR" 245
    $btnRename   = & $mkBtn "Renomear PC"         262
    $btnDominio  = & $mkBtn "Ingresso Dominio"    287

    $btnSair = New-Object System.Windows.Forms.Button
    $btnSair.Text = "SAIR"
    $btnSair.Font = New-Object System.Drawing.Font("Consolas", 8, [System.Drawing.FontStyle]::Bold)
    $btnSair.BackColor = [System.Drawing.Color]::FromArgb(130, 30, 30)
    $btnSair.ForeColor = $corTexto
    $btnSair.FlatStyle = "Flat"
    $btnSair.FlatAppearance.BorderSize = 0
    $btnSair.Size = New-Object System.Drawing.Size(170, 25)
    $btnSair.Location = New-Object System.Drawing.Point(10, 330)
    $panelTools.Controls.Add($btnSair)

    # ----------------------------------------------------------
    # PAINEL ETAPAS (centro)
    # ----------------------------------------------------------
    $panelEtapas = New-Object System.Windows.Forms.Panel
    $panelEtapas.Location = New-Object System.Drawing.Point(208, 38)
    $panelEtapas.Size = New-Object System.Drawing.Size(245, 362)
    $panelEtapas.BackColor = $corPainel
    $form.Controls.Add($panelEtapas)

    $lblEtapas = New-Object System.Windows.Forms.Label
    $lblEtapas.Text = "  PADRONIZACAO -- ETAPAS"
    $lblEtapas.Font = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Bold)
    $lblEtapas.ForeColor = $corAmarelo
    $lblEtapas.Size = New-Object System.Drawing.Size(245, 22)
    $lblEtapas.Location = New-Object System.Drawing.Point(0, 5)
    $panelEtapas.Controls.Add($lblEtapas)

    $cbEtapas = @{}
    $etapas = @(
        @{ Key = "fuso";   Label = "Fuso horario (Manaus UTC-04:00)"; Def = $true },
        @{ Key = "assist"; Label = "Assistencia Remota";              Def = $true },
        @{ Key = "rdp";    Label = "Area de Trabalho Remota (RDP)";  Def = $true },
        @{ Key = "admin";  Label = "Criar conta admin local";         Def = $true },
        @{ Key = "progs";  Label = "Instalar programas";             Def = $true }
    )
    $yE = 30
    foreach ($e in $etapas) {
        $cb = New-Object System.Windows.Forms.CheckBox
        $cb.Text = $e.Label; $cb.Checked = $e.Def
        $cb.Font = New-Object System.Drawing.Font("Consolas", 8)
        $cb.ForeColor = $corTexto; $cb.BackColor = $corPainel
        $cb.Size = New-Object System.Drawing.Size(235, 20)
        $cb.Location = New-Object System.Drawing.Point(5, $yE)
        $panelEtapas.Controls.Add($cb)
        $cbEtapas[$e.Key] = $cb
        $yE += 26
    }

    $lblSep = New-Object System.Windows.Forms.Label
    $lblSep.Text = "  -- Opcional --"
    $lblSep.Font = New-Object System.Drawing.Font("Consolas", 7)
    $lblSep.ForeColor = [System.Drawing.Color]::Gray
    $lblSep.Size = New-Object System.Drawing.Size(235, 14)
    $lblSep.Location = New-Object System.Drawing.Point(0, $yE)
    $panelEtapas.Controls.Add($lblSep)
    $yE += 18

    $lblNome = New-Object System.Windows.Forms.Label
    $lblNome.Text = "  Nome do computador:"
    $lblNome.Font = New-Object System.Drawing.Font("Consolas", 8)
    $lblNome.ForeColor = $corTexto
    $lblNome.Size = New-Object System.Drawing.Size(235, 14)
    $lblNome.Location = New-Object System.Drawing.Point(0, $yE)
    $panelEtapas.Controls.Add($lblNome)
    $yE += 16

    $txtNome = New-Object System.Windows.Forms.TextBox
    $txtNome.Font = New-Object System.Drawing.Font("Consolas", 8)
    $txtNome.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $txtNome.ForeColor = $corTexto
    $txtNome.Size = New-Object System.Drawing.Size(228, 20)
    $txtNome.Location = New-Object System.Drawing.Point(5, $yE)
    $panelEtapas.Controls.Add($txtNome)
    $yE += 26

    $lblDom = New-Object System.Windows.Forms.Label
    $lblDom.Text = "  Dominio / Usuario / Senha:"
    $lblDom.Font = New-Object System.Drawing.Font("Consolas", 8)
    $lblDom.ForeColor = $corTexto
    $lblDom.Size = New-Object System.Drawing.Size(235, 14)
    $lblDom.Location = New-Object System.Drawing.Point(0, $yE)
    $panelEtapas.Controls.Add($lblDom)
    $yE += 16

    $txtDominio = New-Object System.Windows.Forms.TextBox
    $txtDominio.Font = New-Object System.Drawing.Font("Consolas", 8)
    $txtDominio.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $txtDominio.ForeColor = $corTexto
    $txtDominio.Size = New-Object System.Drawing.Size(108, 20)
    $txtDominio.Location = New-Object System.Drawing.Point(5, $yE)
    $panelEtapas.Controls.Add($txtDominio)

    $txtDomUser = New-Object System.Windows.Forms.TextBox
    $txtDomUser.Font = New-Object System.Drawing.Font("Consolas", 8)
    $txtDomUser.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $txtDomUser.ForeColor = [System.Drawing.Color]::Gray
    $txtDomUser.Text = "usuario"
    $txtDomUser.Size = New-Object System.Drawing.Size(55, 20)
    $txtDomUser.Location = New-Object System.Drawing.Point(118, $yE)
    $panelEtapas.Controls.Add($txtDomUser)

    $txtDomPass = New-Object System.Windows.Forms.TextBox
    $txtDomPass.Font = New-Object System.Drawing.Font("Consolas", 8)
    $txtDomPass.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $txtDomPass.ForeColor = [System.Drawing.Color]::Gray
    $txtDomPass.Text = "senha"
    $txtDomPass.Size = New-Object System.Drawing.Size(55, 20)
    $txtDomPass.Location = New-Object System.Drawing.Point(178, $yE)
    $panelEtapas.Controls.Add($txtDomPass)

    # ----------------------------------------------------------
    # PAINEL PROGRAMAS (direito)
    # ----------------------------------------------------------
    $panelProgs = New-Object System.Windows.Forms.Panel
    $panelProgs.Location = New-Object System.Drawing.Point(461, 38)
    $panelProgs.Size = New-Object System.Drawing.Size(459, 362)
    $panelProgs.BackColor = $corPainel
    $form.Controls.Add($panelProgs)

    $lblProgs = New-Object System.Windows.Forms.Label
    $lblProgs.Text = "  PROGRAMAS A INSTALAR"
    $lblProgs.Font = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Bold)
    $lblProgs.ForeColor = $corAmarelo
    $lblProgs.Size = New-Object System.Drawing.Size(459, 22)
    $lblProgs.Location = New-Object System.Drawing.Point(0, 5)
    $panelProgs.Controls.Add($lblProgs)

    $listPrograms = @(
        @{ ChocoId = "Temurin8jre";       Name = "Java (JRE)";     Extra = "" },
        @{ ChocoId = "winrar";            Name = "WinRAR";          Extra = "" },
        @{ ChocoId = "vlc";               Name = "VLC";             Extra = "" },
        @{ ChocoId = "FoxitReader";       Name = "Foxit Reader";    Extra = "" },
        @{ ChocoId = "pdf24";             Name = "PDF24";           Extra = "" },
        @{ ChocoId = "libreoffice-still"; Name = "LibreOffice";     Extra = "" },
        @{ ChocoId = "GoogleChrome";      Name = "Google Chrome";   Extra = "--ignore-checksums" },
        @{ ChocoId = "Firefox";           Name = "Firefox";         Extra = "" },
        @{ ChocoId = "ultravnc";          Name = "UltraVNC (GUI)";  Extra = "" }
    )

    $cbProgs = @{}
    $yP = 32; $col = 10
    foreach ($p in $listPrograms) {
        $cb = New-Object System.Windows.Forms.CheckBox
        $cb.Text = $p.Name; $cb.Checked = $true
        $cb.Font = New-Object System.Drawing.Font("Consolas", 8)
        $cb.ForeColor = $corTexto; $cb.BackColor = $corPainel
        $cb.Size = New-Object System.Drawing.Size(220, 20)
        $cb.Location = New-Object System.Drawing.Point($col, $yP)
        $panelProgs.Controls.Add($cb)
        $cbProgs[$p.ChocoId] = $cb
        if ($col -eq 10) { $col = 230 } else { $col = 10; $yP += 26 }
    }

    # ----------------------------------------------------------
    # BOTAO INICIAR PADRONIZACAO
    # ----------------------------------------------------------
    $btnIniciar = New-Object System.Windows.Forms.Button
    $btnIniciar.Text = "INICIAR PADRONIZACAO"
    $btnIniciar.Font = New-Object System.Drawing.Font("Consolas", 11, [System.Drawing.FontStyle]::Bold)
    $btnIniciar.BackColor = $corBotao
    $btnIniciar.ForeColor = $corTexto
    $btnIniciar.FlatStyle = "Flat"
    $btnIniciar.FlatAppearance.BorderSize = 0
    $btnIniciar.Size = New-Object System.Drawing.Size(712, 40)
    $btnIniciar.Location = New-Object System.Drawing.Point(208, 407)
    $form.Controls.Add($btnIniciar)

    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(208, 452)
    $progressBar.Size = New-Object System.Drawing.Size(712, 18)
    $progressBar.Style = "Continuous"
    $progressBar.Minimum = 0
    $progressBar.Maximum = 1
    $progressBar.Value = 0
    $form.Controls.Add($progressBar)

    $lblLog = New-Object System.Windows.Forms.Label
    $lblLog.Text = "  LOG DE EXECUCAO"
    $lblLog.Font = New-Object System.Drawing.Font("Consolas", 8, [System.Drawing.FontStyle]::Bold)
    $lblLog.ForeColor = $corAmarelo
    $lblLog.Size = New-Object System.Drawing.Size(300, 16)
    $lblLog.Location = New-Object System.Drawing.Point(10, 476)
    $form.Controls.Add($lblLog)

    $rtbLog = New-Object System.Windows.Forms.RichTextBox
    $rtbLog.BackColor = [System.Drawing.Color]::FromArgb(15, 15, 15)
    $rtbLog.ForeColor = $corTexto
    $rtbLog.Font = New-Object System.Drawing.Font("Consolas", 8)
    $rtbLog.ReadOnly = $true
    $rtbLog.Size = New-Object System.Drawing.Size(900, 195)
    $rtbLog.Location = New-Object System.Drawing.Point(10, 494)
    $rtbLog.ScrollBars = "Vertical"
    $form.Controls.Add($rtbLog)

    # ----------------------------------------------------------
    # HELPERS
    # ----------------------------------------------------------
    $log = {
        param([string]$msg, [System.Drawing.Color]$c)
        $rtbLog.SelectionStart = $rtbLog.TextLength
        $rtbLog.SelectionLength = 0
        $rtbLog.SelectionColor = $c
        $rtbLog.AppendText("$msg`n")
        $rtbLog.ScrollToCaret()
        [System.Windows.Forms.Application]::DoEvents()
    }

    $sepLog = {
        param([string]$titulo)
        $rtbLog.Clear()
        & $log "  ================================================" $corDestaque
        & $log "   $titulo" $corAmarelo
        & $log "  ================================================" $corDestaque
    }

    # Captura output de funcoes console (Write-Host, Write-Output, erros) no log
    $capturar = {
        param([scriptblock]$bloco)
        try {
            & $bloco 6>&1 2>&1 | ForEach-Object {
                $t = "$_".TrimEnd()
                if ($t) { & $log "  $t" $corTexto }
            }
        } catch {
            & $log "  [ERRO] $($_.Exception.Message)" $corErro
        }
    }

    $script:guiConcluido    = $false
    $script:guiNeedsRestart = $false

    # ----------------------------------------------------------
    # HANDLERS -- FERRAMENTAS
    # ----------------------------------------------------------
    $btnSair.Add_Click({ $form.Close() })

    $btnInfoPC.Add_Click({
        $btnInfoPC.Enabled = $false
        & $sepLog "INFO DO PC"
        & $capturar { Get-PCInfo }
        $btnInfoPC.Enabled = $true
    })

    $btnChave.Add_Click({
        $btnChave.Enabled = $false
        & $sepLog "CHAVE DO WINDOWS"
        try {
            $key = (Get-WmiObject -Class SoftwareLicensingService -EA Stop).OA3xOriginalProductKey
            if (-not $key) {
                $key = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform" -Name BackupProductKeyDefault -EA SilentlyContinue).BackupProductKeyDefault
            }
            if ($key) {
                & $log "  Chave: $key" $corOk
            } else {
                & $log "  [AVISO] Chave nao encontrada via WMI nem registro." $corAviso
            }
            # Status da licenca via slmgr (sem prompt)
            $tmp = [System.IO.Path]::GetTempFileName()
            Start-Process "cscript.exe" -ArgumentList "//Nologo $env:windir\system32\slmgr.vbs /xpr" -NoNewWindow -Wait -RedirectStandardOutput $tmp
            $status = (Get-Content $tmp -Raw -Encoding OEM -EA SilentlyContinue).Trim()
            Remove-Item $tmp -Force -EA SilentlyContinue
            if ($status) { & $log "  Status: $status" $corTexto }
        } catch {
            & $log "  [ERRO] $($_.Exception.Message)" $corErro
        }
        $btnChave.Enabled = $true
    })

    $btnAtivar.Add_Click({
        & $sepLog "ATIVAR WINDOWS / OFFICE"
        & $log "  [INFO] Abrindo ativador em nova janela admin..." $corAviso
        try {
            Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"irm https://get.activated.win | iex`"" -Verb RunAs
            & $log "  [OK] Janela de ativacao aberta." $corOk
        } catch { & $log "  [ERRO] $($_.Exception.Message)" $corErro }
    })

    $btnAssist.Add_Click({
        & $sepLog "HABILITAR ASSISTENCIA REMOTA"
        try {
            Set-ItemProperty "HKLM:\System\CurrentControlSet\Control\Terminal Server" "fDenyTSConnections" 0 -EA SilentlyContinue
            Set-ItemProperty "HKLM:\System\CurrentControlSet\Control\Terminal Server" "fAllowToGetHelp" 1 -EA SilentlyContinue
            Remove-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" "fAllowToGetHelp" -EA SilentlyContinue
            Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" "fAllowToGetHelp" 1 -EA SilentlyContinue
            Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance" "fAllowToGetHelp" 1 -EA SilentlyContinue
            Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -EA SilentlyContinue
            Enable-NetFirewallRule -DisplayGroup "Área de Trabalho Remota" -EA SilentlyContinue
            Enable-NetFirewallRule -DisplayGroup "Remote Assistance" -EA SilentlyContinue
            Enable-NetFirewallRule -DisplayGroup "Assistencia Remota" -EA SilentlyContinue
            foreach ($sn in @("TermService","SessionEnv","UmRdpService","RemoteRegistry")) {
                $s = Get-Service -Name $sn -EA SilentlyContinue
                if ($s) {
                    if ($s.StartType -eq "Disabled") { Set-Service $sn -StartupType Automatic -EA SilentlyContinue }
                    if ($s.Status -ne "Running")     { Start-Service $sn -EA SilentlyContinue }
                }
            }
            & $log "  [OK] Assistencia Remota habilitada." $corOk
        } catch { & $log "  [ERRO] $($_.Exception.Message)" $corErro }
    })

    $btnTestar.Add_Click({
        $btnTestar.Enabled = $false
        & $sepLog "TESTAR ASSISTENCIA REMOTA"
        & $capturar { Test-RemoteAssistance }
        $btnTestar.Enabled = $true
    })

    $btnRDP.Add_Click({
        & $sepLog "HABILITAR RDP"
        try {
            Set-ItemProperty "HKLM:\System\CurrentControlSet\Control\Terminal Server" "fDenyTSConnections" 0 -EA Stop
            & $log "  [OK] RDP habilitado." $corOk
        } catch { & $log "  [ERRO] $($_.Exception.Message)" $corErro }
    })

    $btnFuso.Add_Click({
        & $sepLog "FUSO HORARIO"
        try {
            Set-TimeZone -Id "SA Western Standard Time" -EA Stop
            & $log "  [OK] Fuso configurado para Manaus (UTC-04:00)." $corOk
        } catch { & $log "  [ERRO] $($_.Exception.Message)" $corErro }
    })

    $btnAdmin.Add_Click({
        & $sepLog "CRIAR CONTA ADMIN"
        try {
            if (-not (Get-LocalUser -Name "admin" -EA SilentlyContinue)) {
                try {
                    New-LocalUser -Name "admin" -NoPassword -Description "Conta criada via GUI" -PasswordNeverExpires $true -EA Stop
                } catch {
                    $r = net user admin "" /add /y 2>&1
                    if ($LASTEXITCODE -ne 0) { throw "net user falhou: $r" }
                }
            }
            Set-LocalUser -Name "admin" -PasswordNeverExpires $true -EA SilentlyContinue
            $grp = (Get-LocalGroup | Where-Object { $_.SID -match "S-1-5-32-544" }).Name
            if (-not $grp) { $grp = "Administradores" }
            $mem = Get-LocalGroupMember -Group $grp | Select-Object -ExpandProperty Name
            if ($mem -notcontains "$env:COMPUTERNAME\admin" -and $mem -notcontains "admin") {
                Add-LocalGroupMember -Group $grp -Member "admin" -EA Stop
            }
            # Remover do grupo Usuarios (adicionado automaticamente pelo Windows ao criar o usuario)
            $usersGrp = (Get-LocalGroup | Where-Object { $_.SID -match "S-1-5-32-545" }).Name
            if (-not $usersGrp) { $usersGrp = "Usuarios" }
            $usersMem = Get-LocalGroupMember -Group $usersGrp -EA SilentlyContinue | Select-Object -ExpandProperty Name
            if ($usersMem -contains "$env:COMPUTERNAME\admin" -or $usersMem -contains "admin") {
                Remove-LocalGroupMember -Group $usersGrp -Member "admin" -EA SilentlyContinue
            }
            & $log "  [OK] Conta admin configurada no grupo '$grp'." $corOk
        } catch { & $log "  [ERRO] $($_.Exception.Message)" $corErro }
    })

    $btnRename.Add_Click({
        $dlg = New-Object System.Windows.Forms.Form
        $dlg.Text = "Renomear Computador"
        $dlg.Size = New-Object System.Drawing.Size(340, 130)
        $dlg.StartPosition = "CenterParent"
        $dlg.BackColor = $corFundo; $dlg.ForeColor = $corTexto
        $dlg.FormBorderStyle = "FixedDialog"
        $dlg.MaximizeBox = $false; $dlg.MinimizeBox = $false

        $lbl = New-Object System.Windows.Forms.Label
        $lbl.Text = "Novo nome do computador:"
        $lbl.Location = New-Object System.Drawing.Point(10, 15)
        $lbl.Size = New-Object System.Drawing.Size(310, 16)
        $lbl.Font = New-Object System.Drawing.Font("Consolas", 8)
        $dlg.Controls.Add($lbl)

        $tb = New-Object System.Windows.Forms.TextBox
        $tb.Location = New-Object System.Drawing.Point(10, 34)
        $tb.Size = New-Object System.Drawing.Size(310, 22)
        $tb.Font = New-Object System.Drawing.Font("Consolas", 8)
        $tb.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60); $tb.ForeColor = $corTexto
        $dlg.Controls.Add($tb)

        $bOk = New-Object System.Windows.Forms.Button
        $bOk.Text = "OK"; $bOk.Location = New-Object System.Drawing.Point(148, 65)
        $bOk.Size = New-Object System.Drawing.Size(80, 26)
        $bOk.BackColor = $corBotao; $bOk.ForeColor = $corTexto; $bOk.FlatStyle = "Flat"
        $bOk.Add_Click({ $dlg.DialogResult = "OK"; $dlg.Close() })
        $dlg.Controls.Add($bOk)

        $bCan = New-Object System.Windows.Forms.Button
        $bCan.Text = "Cancelar"; $bCan.Location = New-Object System.Drawing.Point(238, 65)
        $bCan.Size = New-Object System.Drawing.Size(82, 26)
        $bCan.BackColor = [System.Drawing.Color]::FromArgb(80,80,80); $bCan.ForeColor = $corTexto; $bCan.FlatStyle = "Flat"
        $bCan.Add_Click({ $dlg.DialogResult = "Cancel"; $dlg.Close() })
        $dlg.Controls.Add($bCan)

        $dlg.AcceptButton = $bOk; $dlg.CancelButton = $bCan

        if ($dlg.ShowDialog($form) -eq "OK") {
            $novoNome = $tb.Text.Trim()
            if ($novoNome) {
                & $sepLog "RENOMEAR COMPUTADOR"
                try {
                    Rename-Computer -NewName $novoNome -Force -EA Stop
                    $script:guiNeedsRestart = $true
                    & $log "  [OK] Renomeado para '$novoNome'. Reinicio necessario." $corOk
                } catch { & $log "  [ERRO] $($_.Exception.Message)" $corErro }
            }
        }
    })

    $btnDominio.Add_Click({
        $dlg = New-Object System.Windows.Forms.Form
        $dlg.Text = "Ingresso no Dominio"
        $dlg.Size = New-Object System.Drawing.Size(340, 195)
        $dlg.StartPosition = "CenterParent"
        $dlg.BackColor = $corFundo; $dlg.ForeColor = $corTexto
        $dlg.FormBorderStyle = "FixedDialog"
        $dlg.MaximizeBox = $false; $dlg.MinimizeBox = $false

        $addLbl = { param([string]$t,[int]$y)
            $l = New-Object System.Windows.Forms.Label
            $l.Text = $t; $l.Location = New-Object System.Drawing.Point(10,$y)
            $l.Size = New-Object System.Drawing.Size(310,14)
            $l.Font = New-Object System.Drawing.Font("Consolas",8)
            $dlg.Controls.Add($l)
        }
        $addTb = { param([int]$y,[bool]$pwd=$false)
            $t = New-Object System.Windows.Forms.TextBox
            $t.Location = New-Object System.Drawing.Point(10,$y)
            $t.Size = New-Object System.Drawing.Size(310,22)
            $t.Font = New-Object System.Drawing.Font("Consolas",8)
            $t.BackColor = [System.Drawing.Color]::FromArgb(60,60,60); $t.ForeColor = $corTexto
            if ($pwd) { $t.UseSystemPasswordChar = $true }
            $dlg.Controls.Add($t); return $t
        }

        & $addLbl "Dominio (ex: semsa.am.gov.br):" 10
        $tbDom = & $addTb 26
        & $addLbl "Usuario:" 55
        $tbUsr = & $addTb 71
        & $addLbl "Senha:" 100
        $tbPas = & $addTb 116 $true

        $bOk = New-Object System.Windows.Forms.Button
        $bOk.Text = "Ingressar"; $bOk.Location = New-Object System.Drawing.Point(115, 152)
        $bOk.Size = New-Object System.Drawing.Size(95, 26)
        $bOk.BackColor = $corBotao; $bOk.ForeColor = $corTexto; $bOk.FlatStyle = "Flat"
        $bOk.Add_Click({ $dlg.DialogResult = "OK"; $dlg.Close() })
        $dlg.Controls.Add($bOk)

        $bCan = New-Object System.Windows.Forms.Button
        $bCan.Text = "Cancelar"; $bCan.Location = New-Object System.Drawing.Point(220, 152)
        $bCan.Size = New-Object System.Drawing.Size(95, 26)
        $bCan.BackColor = [System.Drawing.Color]::FromArgb(80,80,80); $bCan.ForeColor = $corTexto; $bCan.FlatStyle = "Flat"
        $bCan.Add_Click({ $dlg.DialogResult = "Cancel"; $dlg.Close() })
        $dlg.Controls.Add($bCan)

        $dlg.AcceptButton = $bOk; $dlg.CancelButton = $bCan

        if ($dlg.ShowDialog($form) -eq "OK") {
            $dom = $tbDom.Text.Trim(); $usr = $tbUsr.Text.Trim(); $pas = $tbPas.Text
            if ($dom -and $usr) {
                & $sepLog "INGRESSO NO DOMINIO"
                & $log "  [INFO] Ingressando em '$dom'..." $corInfo
                try {
                    $sp   = ConvertTo-SecureString $pas -AsPlainText -Force
                    $cred = New-Object System.Management.Automation.PSCredential($usr, $sp)
                    Add-Computer -DomainName $dom -Credential $cred -Force -EA Stop
                    $script:guiNeedsRestart = $true
                    & $log "  [OK] Ingressou no dominio '$dom'. Reinicio necessario." $corOk
                } catch { & $log "  [ERRO] $($_.Exception.Message)" $corErro }
            } else {
                & $log "  [AVISO] Dominio e usuario sao obrigatorios." $corAviso
            }
        }
    })

    # ----------------------------------------------------------
    # HANDLER -- INICIAR PADRONIZACAO
    # ----------------------------------------------------------
    $btnIniciar.Add_Click({
        if ($script:guiConcluido) { $form.Close(); return }

        $btnIniciar.Enabled = $false
        $btnIniciar.Text = "EXECUTANDO..."

        & $log "" $corInfo
        & $log "  ================================================" $corDestaque
        & $log "   INICIANDO PADRONIZACAO AUTOMATICA" $corAmarelo
        & $log "  ================================================" $corDestaque

        # Etapa 1 - Fuso
        if ($cbEtapas["fuso"].Checked) {
            & $log "  [1] Configurando fuso horario Manaus..." $corInfo
            try {
                Set-TimeZone -Id "SA Western Standard Time" -EA Stop
                & $log "      [OK] Fuso configurado." $corOk
            } catch { & $log "      [ERRO] $($_.Exception.Message)" $corErro }
        }

        # Etapa 2 - Assistencia Remota
        if ($cbEtapas["assist"].Checked) {
            & $log "  [2] Habilitando Assistencia Remota..." $corInfo
            try {
                Set-ItemProperty "HKLM:\System\CurrentControlSet\Control\Terminal Server" "fDenyTSConnections" 0 -EA SilentlyContinue
                Set-ItemProperty "HKLM:\System\CurrentControlSet\Control\Terminal Server" "fAllowToGetHelp" 1 -EA SilentlyContinue
                Remove-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" "fAllowToGetHelp" -EA SilentlyContinue
                Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" "fAllowToGetHelp" 1 -EA SilentlyContinue
                Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance" "fAllowToGetHelp" 1 -EA SilentlyContinue
                Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -EA SilentlyContinue
                Enable-NetFirewallRule -DisplayGroup "Área de Trabalho Remota" -EA SilentlyContinue
                Enable-NetFirewallRule -DisplayGroup "Remote Assistance" -EA SilentlyContinue
                Enable-NetFirewallRule -DisplayGroup "Assistencia Remota" -EA SilentlyContinue
                foreach ($sn in @("TermService","SessionEnv","UmRdpService","RemoteRegistry")) {
                    $s = Get-Service -Name $sn -EA SilentlyContinue
                    if ($s) {
                        if ($s.StartType -eq "Disabled") { Set-Service $sn -StartupType Automatic -EA SilentlyContinue }
                        if ($s.Status -ne "Running")     { Start-Service $sn -EA SilentlyContinue }
                    }
                }
                & $log "      [OK] Assistencia Remota habilitada." $corOk
            } catch { & $log "      [ERRO] $($_.Exception.Message)" $corErro }
        }

        # Etapa 3 - RDP
        if ($cbEtapas["rdp"].Checked) {
            & $log "  [3] Habilitando RDP..." $corInfo
            try {
                Set-ItemProperty "HKLM:\System\CurrentControlSet\Control\Terminal Server" "fDenyTSConnections" 0 -EA Stop
                & $log "      [OK] RDP habilitado." $corOk
            } catch { & $log "      [ERRO] $($_.Exception.Message)" $corErro }
        }

        # Etapa 4 - Nome do computador
        if ($txtNome.Text.Trim() -ne "") {
            & $log "  [4] Renomeando para '$($txtNome.Text.Trim())'..." $corInfo
            try {
                Rename-Computer -NewName $txtNome.Text.Trim() -Force -EA Stop
                $script:guiNeedsRestart = $true
                & $log "      [OK] Renomeado. Reinicializacao necessaria." $corOk
            } catch { & $log "      [ERRO] $($_.Exception.Message)" $corErro }
        }

        # Etapa 5 - Dominio
        $domVal = $txtDominio.Text.Trim()
        if ($domVal -ne "") {
            & $log "  [5] Ingressando no dominio '$domVal'..." $corInfo
            try {
                $sp   = ConvertTo-SecureString $txtDomPass.Text -AsPlainText -Force
                $cred = New-Object System.Management.Automation.PSCredential($txtDomUser.Text, $sp)
                Add-Computer -DomainName $domVal -Credential $cred -Force -EA Stop
                $script:guiNeedsRestart = $true
                & $log "      [OK] Ingressou no dominio. Reinicializacao necessaria." $corOk
            } catch { & $log "      [ERRO] $($_.Exception.Message)" $corErro }
        }

        # Etapa 6 - Conta admin
        if ($cbEtapas["admin"].Checked) {
            & $log "  [6] Criando conta admin..." $corInfo
            try {
                if (-not (Get-LocalUser -Name "admin" -EA SilentlyContinue)) {
                    try {
                        New-LocalUser -Name "admin" -NoPassword -Description "Conta criada via GUI" -PasswordNeverExpires $true -EA Stop
                    } catch {
                        $r = net user admin "" /add /y 2>&1
                        if ($LASTEXITCODE -ne 0) { throw "net user falhou: $r" }
                    }
                }
                Set-LocalUser -Name "admin" -PasswordNeverExpires $true -EA SilentlyContinue
                $grp = (Get-LocalGroup | Where-Object { $_.SID -match "S-1-5-32-544" }).Name
                if (-not $grp) { $grp = "Administradores" }
                $mem = Get-LocalGroupMember -Group $grp | Select-Object -ExpandProperty Name
                if ($mem -notcontains "$env:COMPUTERNAME\admin" -and $mem -notcontains "admin") {
                    Add-LocalGroupMember -Group $grp -Member "admin" -EA Stop
                }
                & $log "      [OK] Conta admin configurada no grupo '$grp'." $corOk
            } catch { & $log "      [ERRO] $($_.Exception.Message)" $corErro }
        }

        # Etapa 7 - Programas
        if ($cbEtapas["progs"].Checked) {
            & $log "" $corInfo
            & $log "  [7] Instalando programas via Chocolatey..." $corInfo

            $chocoOk = $false
            if (Get-Command choco -EA SilentlyContinue) {
                $chocoOk = $true
                & $log "      Chocolatey ja instalado." $corOk
            } else {
                & $log "      Chocolatey nao encontrado. Instalando..." $corAviso
                try {
                    Set-ExecutionPolicy Bypass -Scope Process -Force
                    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
                    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
                    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
                                [System.Environment]::GetEnvironmentVariable("Path","User")
                    if (Get-Command choco -EA SilentlyContinue) {
                        $chocoOk = $true
                        & $log "      [OK] Chocolatey instalado." $corOk
                    } else { throw "choco nao reconhecido apos instalacao." }
                } catch {
                    & $log "      [ERRO] Falha no Chocolatey: $($_.Exception.Message)" $corErro
                }
            }

            if ($chocoOk) {
                $selecionados = $listPrograms | Where-Object { $cbProgs[$_.ChocoId].Checked -and $_.ChocoId -ne "ultravnc" }
                $vncSelecionado = $cbProgs["ultravnc"].Checked
                $extraVnc = if ($vncSelecionado) { 1 } else { 0 }
                $progressBar.Maximum = [Math]::Max($selecionados.Count + $extraVnc, 1)
                $progressBar.Value = 0

                $runChoco = {
                    param([string]$chocoArgs)
                    $tmpFile = [System.IO.Path]::GetTempFileName()
                    $exitCode = $null
                    try {
                        $proc = Start-Process -FilePath "choco" -ArgumentList $chocoArgs `
                            -RedirectStandardOutput $tmpFile -NoNewWindow -PassThru
                        $linhasVistas = 0
                        while (-not $proc.HasExited) {
                            try {
                                $fs = [System.IO.FileStream]::new($tmpFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
                                $sr = New-Object System.IO.StreamReader($fs)
                                $conteudo = $sr.ReadToEnd(); $sr.Dispose(); $fs.Dispose()
                                $linhas = $conteudo -split "`r?`n"
                                for ($i = $linhasVistas; $i -lt ($linhas.Count - 1); $i++) {
                                    $t = $linhas[$i].Trim()
                                    if ($t -and $t -notmatch '^Progress:') { & $log "        $t" $corTexto }
                                }
                                $linhasVistas = [Math]::Max($linhas.Count - 1, $linhasVistas)
                            } catch {}
                            [System.Windows.Forms.Application]::DoEvents()
                            Start-Sleep -Milliseconds 300
                        }
                        $proc.WaitForExit()
                        $exitCode = [int]$proc.ExitCode
                        try {
                            $fs = [System.IO.FileStream]::new($tmpFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
                            $sr = New-Object System.IO.StreamReader($fs)
                            $conteudo = $sr.ReadToEnd(); $sr.Dispose(); $fs.Dispose()
                            $linhas = $conteudo -split "`r?`n"
                            for ($i = $linhasVistas; $i -lt $linhas.Count; $i++) {
                                $t = $linhas[$i].Trim()
                                if ($t -and $t -notmatch '^Progress:') { & $log "        $t" $corTexto }
                            }
                        } catch {}
                    } finally {
                        Remove-Item $tmpFile -EA SilentlyContinue
                    }
                    return $exitCode
                }

                foreach ($p in $selecionados) {
                    & $log "      Instalando $($p.Name)..." $corInfo
                    $argStr = "install $($p.ChocoId) -y --no-progress"
                    if ($p.Extra) { $argStr += " $($p.Extra)" }
                    $codigo = & $runChoco $argStr
                    if ($codigo -eq 0) {
                        & $log "      [OK] $($p.Name)" $corOk
                    } else {
                        & $log "      [ERRO] $($p.Name) (cod: $codigo)" $corErro
                    }
                    $progressBar.Value = [Math]::Min($progressBar.Value + 1, $progressBar.Maximum)
                    [System.Windows.Forms.Application]::DoEvents()
                }

                if ($vncSelecionado) {
                    & $log "" $corInfo
                    & $log "      Abrindo instalador do UltraVNC (interativo)..." $corAviso
                    & $log "      Configure e finalize o instalador para continuar." $corAviso
                    $codigo = & $runChoco 'install ultravnc --override-arguments --install-arguments="/SP- /NORESTART" -y'
                    if ($codigo -eq 0) {
                        & $log "      [OK] UltraVNC instalado." $corOk
                    } else {
                        & $log "      [ERRO] UltraVNC falhou (cod: $codigo)." $corErro
                    }
                    $progressBar.Value = $progressBar.Maximum
                }
            }
        }

        & $log "" $corInfo
        & $log "  ================================================" $corAviso
        & $log "  ATENCAO -- ETAPAS MANUAIS RESTANTES:" $corAviso
        & $log "  [1] Certificado Fortinet: certmgr.msc" $corAviso
        & $log "  [2] Kaspersky: \\balbina\suporte\Kasper ok\" $corAviso
        & $log "  ================================================" $corAviso

        $script:guiConcluido = $true
        $btnIniciar.Text = "CONCLUIDO -- Clique para fechar"
        $btnIniciar.BackColor = [System.Drawing.Color]::FromArgb(0, 110, 0)
        $btnIniciar.Enabled = $true

        if ($script:guiNeedsRestart) {
            $resposta = [System.Windows.Forms.MessageBox]::Show(
                "Algumas alteracoes exigem reinicializacao para entrar em vigor.`n`nDeseja reiniciar agora?",
                "Reiniciar o computador?",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            if ($resposta -eq [System.Windows.Forms.DialogResult]::Yes) {
                Restart-Computer -Force
            }
        }
    })

    [void]$form.ShowDialog()
}

# Submenu de padronizacao manual
function Show-ManualMenu {
    do {
        Clear-Host
        Write-Host "==================================================="  -ForegroundColor Cyan
        Write-Host "             PADRONIZACAO MANUAL                     " -ForegroundColor Yellow
        Write-Host "==================================================="  -ForegroundColor Cyan
        Write-Host ""
        Write-Host " [1]  Definir fuso horario"
        Write-Host " [2]  Instalar programas padrao"
        Write-Host " [3]  Habilitar Assistencia Remota"
        Write-Host " [4]  Testar configuracao da Assistencia Remota"
        Write-Host " [5]  Habilitar Area de Trabalho Remota"
        Write-Host " [6]  Alterar nome do computador"
        Write-Host " [7]  Definir nome do dominio"
        Write-Host " [8]  Criar conta admin"
        Write-Host ""
        Write-Host " [0]  Voltar ao menu principal" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "==================================================="  -ForegroundColor Cyan

        $option = Read-Host "Escolha uma opcao"

        try {
            switch ($option) {
                "1" { Set-TimeZoneOption; Pause }
                "2" { Install-StandardPrograms; Pause }
                "3" { Enable-RemoteAssistance; Pause }
                "4" { Test-RemoteAssistance; Pause }
                "5" { Enable-RemoteDesktop; Pause }
                "6" { Set-ComputerName; Pause }
                "7" { Set-DomainName; Pause }
                "8" { Create-AdminAccount; Pause }
                "0" { return }
                default {
                    Write-Host " [ERRO] Opcao invalida, tente novamente." -ForegroundColor Red
                    Pause
                }
            }
        } catch {
            Write-Host " [ERRO] Ocorreu um erro ao executar a operacao: $($_.Exception.Message)" -ForegroundColor Red
            Pause
        }
    } while ($option -ne "0")
}

# Menu principal
function Show-Menu {
    do {
        Clear-Host
        Write-Host "==================================================="  -ForegroundColor Cyan
        Write-Host "                 MENU DE OPERACOES                  " -ForegroundColor Yellow
        Write-Host "==================================================="  -ForegroundColor Cyan
        Write-Host ""
        Write-Host " [1]  Informacoes do PC" -ForegroundColor Green
        Write-Host " [2]  Obter chave do Windows"
        Write-Host " [3]  Ativar Windows/Office"
        Write-Host " [4]  GUI Padronizacao" -ForegroundColor Yellow
        Write-Host " [5]  Padronizacao Automatica" -ForegroundColor Magenta
        Write-Host " [6]  Padronizacao Manual" -ForegroundColor Cyan
        Write-Host " [7]  Sair" -ForegroundColor Red
        Write-Host ""
        Write-Host "==================================================="  -ForegroundColor Cyan

        $option = Read-Host "Escolha uma opcao"

        try {
            switch ($option) {
                "1" { Get-PCInfo; Pause }
                "2" { Get-WindowsKey; Pause }
                "3" { Activate-WindowsOffice; Pause }
                "4" { Show-PadronizacaoGUI }
                "5" { Start-AutoPadronizacao; Pause }
                "6" { Show-ManualMenu }
                "7" {
                    Write-Host "Saindo do programa..." -ForegroundColor Yellow
                    Exit
                }
                default {
                    Write-Host " [ERRO] Opcao invalida, tente novamente." -ForegroundColor Red
                    Pause
                }
            }
        } catch {
            Write-Host " [ERRO] Ocorreu um erro ao executar a operacao: $($_.Exception.Message)" -ForegroundColor Red
            Pause
        }
    } while ($option -ne "7")
}

# Funcao para avisar o usuario como reiniciar o script como administrador
function Restart-ScriptAsAdmin {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        $scriptPath = $MyInvocation.MyCommand.Path
        
        if ([string]::IsNullOrEmpty($scriptPath)) {
            # Execucao na memoria (via iex)
            Write-Host "`n[INSTRUCOES] O script esta sendo executado da memoria." -ForegroundColor Yellow
            Write-Host "Para executar como Administrador e ter acesso a todas as funcoes:" -ForegroundColor Cyan
            Write-Host "1. Abra o Menu Iniciar e digite 'PowerShell'" -ForegroundColor White
            Write-Host "2. Selecione 'Executar como Administrador'" -ForegroundColor White
            Write-Host "3. Execute novamente o comando de instalacao (irm ... | iex)" -ForegroundColor White
            Write-Host "`nPressione qualquer tecla para continuar sem privilegios administrativos..." -ForegroundColor Cyan
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            return $false
        } else {
            try {
                Write-Host " [INFO] Tentando reiniciar o script como administrador..." -ForegroundColor Cyan
                Write-Host " [INFO] Uma nova janela do PowerShell sera aberta. Por favor, execute o script novamente nela." -ForegroundColor Cyan
                
                # Metodo alternativo: criar um atalho que execute como administrador
                $tempDir = [System.IO.Path]::GetTempPath()
                $shortcutPath = Join-Path $tempDir "ExecutarComoAdmin.lnk"
                
                # Criar um objeto de atalho do Windows
                $WshShell = New-Object -ComObject WScript.Shell
                $Shortcut = $WshShell.CreateShortcut($shortcutPath)
                $Shortcut.TargetPath = "powershell.exe"
                $Shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
                $Shortcut.WorkingDirectory = Split-Path $scriptPath -Parent
                $Shortcut.WindowStyle = 1  # Normal window
                $Shortcut.Save()
                
                # Exibir instrucoes para o usuario
                Write-Host "[INSTRUCOES] Um atalho foi criado em: $shortcutPath" -ForegroundColor Yellow
                Write-Host "[INSTRUCOES] Por favor, clique com o botao direito neste atalho e selecione 'Executar como administrador'" -ForegroundColor Yellow
                
                # Abrir o explorador de arquivos no local do atalho
                Start-Process explorer.exe -ArgumentList "/select,`"$shortcutPath`""
                
                # Aguardar para que o usuario possa ler as instrucoes
                Write-Host " [INFO] Pressione qualquer tecla para continuar sem privilegios administrativos..." -ForegroundColor Cyan
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                
                return $false
            } catch {
                Write-Host " [ERRO] Nao foi possivel criar o atalho para execucao administrativa: $($_.Exception.Message)" -ForegroundColor Red
                return $false
            }
        }
    }
    return $true
}

# Verificar se o script esta sendo executado como administrador
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(
        "Este script nao esta sendo executado como Administrador.`n`nAlgumas funcoes podem falhar (configuracoes de registro, firewall, servicos).`n`nFeche e reabra o PowerShell como Administrador para funcionalidade completa.",
        "Aviso — Sem privilegios administrativos",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    ) | Out-Null
}

# Por ultimo, abrimos a GUI principal
Show-PadronizacaoGUI

