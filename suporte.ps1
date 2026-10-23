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

    $assetTag = Get-CimInstance -ClassName Win32_SystemEnclosure | Select-Object -ExpandProperty SMBIOSAssetTag
    if (-not $assetTag) { $assetTag = "Nao disponivel" }

    $serialNumber = Get-CimInstance -ClassName Win32_BIOS | Select-Object -ExpandProperty SerialNumber
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
        $realPrinters = Get-CimInstance -ClassName Win32_Printer -ErrorAction SilentlyContinue |
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
            
            $ddrType = $ramTypes[$moduleIndex - 1]

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

function Get-NomeStatusLicenca {
    param([int]$Status)
    $nomes = @{
        0 = "Nao licenciado"; 1 = "Licenciado (ATIVO)"; 2 = "Tolerancia inicial (OOB)"
        3 = "Tolerancia (OOT)"; 4 = "Tolerancia - nao genuino"; 5 = "Notificacao (NAO ATIVADO)"
        6 = "Tolerancia estendida"
    }
    return $nomes[$Status]
}

function ConvertTo-CanalLicenca {
    param([string]$Descricao)
    if ($Descricao -match "VOLUME_MAK") { return "MAK (volume)" }
    if ($Descricao -match "VOLUME_KMS|KMSCLIENT") { return "KMS (volume)" }
    if ($Descricao -match "OEM") { return "OEM" }
    if ($Descricao -match "RETAIL\(Subscription\)|Subscription") { return "Retail (assinatura Microsoft 365)" }
    if ($Descricao -match "RETAIL") { return "Retail" }
    if ($Descricao -match "TIMEBASED|EVAL") { return "Avaliacao (temporaria)" }
    if ($Descricao) { return "Outro" }
    return "Desconhecido"
}

function Get-ResumoLicenca {
    param([string]$ChaveParcial, [int]$Status, [string]$Canal)
    $chave = if ($ChaveParcial) { "SIM (final $ChaveParcial)" } else { "NAO" }
    $ativo = if ($Status -eq 1) { "SIM" } elseif ($Status -in 2, 3, 6) { "EM TOLERANCIA" } else { "NAO" }
    return "Chave: $chave | Ativado: $ativo | Tipo: $Canal"
}

function Get-WindowsLicenseInfo {
    $lic = @(Get-CimInstance SoftwareLicensingProduct -EA SilentlyContinue `
        -Filter "ApplicationId='55c92734-d682-4d71-983e-d6ec3f16059f' AND PartialProductKey IS NOT NULL" |
        Where-Object { -not $_.LicenseIsAddon })
    if ($lic.Count -eq 0) { return $null }
    $l = $lic | Sort-Object { $_.LicenseStatus -ne 1 } | Select-Object -First 1
    $bios = $null
    try { $bios = (Get-CimInstance SoftwareLicensingService -EA Stop).OA3xOriginalProductKey } catch {}
    $kms = if ($l.KeyManagementServiceMachine) { $l.KeyManagementServiceMachine } else { $l.DiscoveredKeyManagementServiceMachineName }
    return [PSCustomObject]@{
        Nome          = $l.Name
        Descricao     = $l.Description
        Canal         = ConvertTo-CanalLicenca $l.Description
        Status        = [int]$l.LicenseStatus
        StatusNome    = Get-NomeStatusLicenca ([int]$l.LicenseStatus)
        ChaveParcial  = $l.PartialProductKey
        KmsHost       = $kms
        DiasRestantes = [Math]::Round(([double]$l.GracePeriodRemaining) / 1440)
        BiosChaveOem  = $bios
    }
}

function Get-OfficeStatus {
    $motivos = @{
        "0xC004F009" = "periodo de tolerancia expirou"
        "0xC004F074" = "servidor KMS inacessivel"
        "0xC004F00F" = "hardware mudou demais (ID fora da tolerancia)"
        "0xC004F050" = "chave de produto invalida"
        "0xC004F038" = "contagem do KMS insuficiente"
    }

    $instalacao = @()
    $c2r = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration" -EA SilentlyContinue
    if ($c2r -and $c2r.ProductReleaseIds) {
        $instalacao += "Click-to-Run: $($c2r.ProductReleaseIds) | versao $($c2r.VersionToReport) | $($c2r.Platform)"
    }
    $uninstKeys = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
                  "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    Get-ItemProperty $uninstKeys -EA SilentlyContinue |
        Where-Object { $_.DisplayName -match '^Microsoft (Office|365)' -and
                       $_.DisplayName -notmatch 'Update|Runtime|Language|Proofing|Teams|Tools|Interop|Shared|Visio|Project' } |
        Select-Object -First 4 | ForEach-Object { $instalacao += "$($_.DisplayName) | versao $($_.DisplayVersion)" }

    $licencas = @()
    try {
        $licencas += @(Get-CimInstance SoftwareLicensingProduct -EA Stop `
            -Filter "ApplicationId='0ff1ce15-a989-479d-af46-f275c6370663' AND PartialProductKey IS NOT NULL")
    } catch {}
    try {
        $licencas += @(Get-CimInstance OfficeSoftwareProtectionProduct -EA Stop -Filter "PartialProductKey IS NOT NULL")
    } catch {}

    $itens = foreach ($l in $licencas) {
        $cod = "0x{0:X8}" -f [uint32]$l.LicenseStatusReason
        [PSCustomObject]@{
            Nome        = $l.Name
            Descricao   = $l.Description
            Canal       = ConvertTo-CanalLicenca $l.Description
            Status      = [int]$l.LicenseStatus
            StatusNome  = Get-NomeStatusLicenca ([int]$l.LicenseStatus)
            ChaveParcial = $l.PartialProductKey
            CodigoMotivo = $cod
            Motivo      = $motivos[$cod]
            DiasRestantes = [Math]::Round(([double]$l.GracePeriodRemaining) / 1440)
        }
    }
    $contas = @()
    Get-ChildItem Registry::HKEY_USERS -EA SilentlyContinue |
        Where-Object { $_.PSChildName -match '^S-1-5-21-[\d-]+$' } | ForEach-Object {
            $sid = $_.PSChildName
            $usuario = try { (New-Object System.Security.Principal.SecurityIdentifier $sid).Translate([System.Security.Principal.NTAccount]).Value } catch { $sid }
            Get-ChildItem "Registry::HKEY_USERS\$sid\Software\Microsoft\Office\16.0\Common\Identity\Identities" -EA SilentlyContinue | ForEach-Object {
                $p = Get-ItemProperty $_.PSPath -EA SilentlyContinue
                if ($p.EmailAddress -and -not ($contas | Where-Object { $_.Usuario -eq $usuario -and $_.Email -eq $p.EmailAddress })) {
                    $contas += [PSCustomObject]@{ Usuario = $usuario; Email = $p.EmailAddress }
                }
            }
        }

    return [PSCustomObject]@{ Instalacao = @($instalacao); Licencas = @($itens); Contas = @($contas) }
}

function Get-PadronizacaoStatus {
    param(
        [string]$NomeEsperado = "",
        [string]$DominioEsperado = "",
        [object[]]$Programas = @(),
        [string]$CertPath = "",
        [bool]$CertIsDir = $false,
        [object[]]$CertificadosPadrao = @()
    )
    $res = New-Object System.Collections.ArrayList
    $add = {
        param([string]$etapa, [string]$item, [string]$estado, [string]$detalhe)
        [void]$res.Add([PSCustomObject]@{ Etapa = $etapa; Item = $item; Estado = $estado; Detalhe = $detalhe })
    }
    $fwRdp = "@FirewallAPI.dll,-28752"

    # 1 - Fuso horario
    $e = "1. Fuso horario"
    try {
        [System.TimeZoneInfo]::ClearCachedData()
        $tz = [System.TimeZoneInfo]::Local
        if ($tz.Id -eq "SA Western Standard Time") { & $add $e "Fuso Manaus (UTC-04:00)" "OK" "" }
        else { & $add $e "Fuso Manaus (UTC-04:00)" "FALTA" "atual: $($tz.Id)" }
    } catch { & $add $e "Fuso Manaus (UTC-04:00)" "AVISO" $_.Exception.Message }

    # 2 - Assistencia Remota
    $e = "2. Assistencia Remota"
    $raReg = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance" -EA SilentlyContinue).fAllowToGetHelp
    $raPol = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -EA SilentlyContinue).fAllowToGetHelp
    if ($raReg -eq 1 -and $raPol -ne 0) { & $add $e "Permitida no registro" "OK" "" }
    elseif ($raPol -eq 0) { & $add $e "Permitida no registro" "FALTA" "bloqueada por politica (fAllowToGetHelp=0)" }
    else { & $add $e "Permitida no registro" "FALTA" "fAllowToGetHelp nao esta em 1" }
    try {
        $regrasRa = @(Get-NetFirewallRule -EA Stop | Where-Object { $_.Name -like "RemoteAssistance*" })
        if ($regrasRa.Count -eq 0) { & $add $e "Firewall" "INFO" "este Windows nao tem regras de Assistencia Remota" }
        elseif (@($regrasRa | Where-Object { $_.Enabled -eq "True" }).Count -gt 0) { & $add $e "Firewall" "OK" "" }
        else { & $add $e "Firewall" "FALTA" "regras de Assistencia Remota desabilitadas" }
    } catch { & $add $e "Firewall" "AVISO" "nao foi possivel consultar o firewall" }
    $parados = @()
    foreach ($sn in @("TermService", "SessionEnv", "UmRdpService", "RemoteRegistry")) {
        $s = Get-Service -Name $sn -EA SilentlyContinue
        if ($s -and $s.Status -ne "Running") { $parados += $sn }
    }
    if ($parados.Count -eq 0) { & $add $e "Servicos (TermService, SessionEnv, UmRdpService, RemoteRegistry)" "OK" "" }
    else { & $add $e "Servicos" "FALTA" "parados: $($parados -join ', ')" }

    # 3 - RDP
    $e = "3. RDP"
    $deny = (Get-ItemProperty "HKLM:\System\CurrentControlSet\Control\Terminal Server" -EA SilentlyContinue).fDenyTSConnections
    if ($deny -eq 0) { & $add $e "RDP habilitado no registro" "OK" "" }
    else { & $add $e "RDP habilitado no registro" "FALTA" "fDenyTSConnections = $deny" }
    try {
        $regrasRdp = @(Get-NetFirewallRule -Group $fwRdp -EA Stop)
        if (@($regrasRdp | Where-Object { $_.Enabled -eq "True" }).Count -gt 0) { & $add $e "Firewall do RDP" "OK" "" }
        else { & $add $e "Firewall do RDP" "FALTA" "regras do grupo Area de Trabalho Remota desabilitadas" }
    } catch { & $add $e "Firewall do RDP" "AVISO" "nao foi possivel consultar o firewall" }
    try {
        $escuta = @(Get-NetTCPConnection -LocalPort 3389 -State Listen -EA Stop)
        if ($escuta.Count -gt 0) { & $add $e "Porta 3389 escutando" "OK" "" }
        else { & $add $e "Porta 3389 escutando" "FALTA" "nenhum servico escutando (TermService parado?)" }
    } catch { & $add $e "Porta 3389 escutando" "AVISO" "nao foi possivel consultar as portas" }

    # 4 - Nome do computador
    $e = "4. Nome do computador"
    if ($NomeEsperado) {
        if ($env:COMPUTERNAME -ieq $NomeEsperado) { & $add $e "Nome = $NomeEsperado" "OK" "" }
        else { & $add $e "Nome = $NomeEsperado" "FALTA" "atual: $env:COMPUTERNAME" }
    } else { & $add $e "Nome atual" "INFO" $env:COMPUTERNAME }

    # 5 - Dominio
    $e = "5. Dominio"
    $cs = Get-CimInstance Win32_ComputerSystem -EA SilentlyContinue
    if ($DominioEsperado) {
        $dom = "$($cs.Domain)"
        $ok = $cs.PartOfDomain -and ($dom -ieq $DominioEsperado -or $dom -like "$DominioEsperado.*" -or $DominioEsperado -like "$dom.*")
        if ($ok) { & $add $e "Ingressado em $DominioEsperado" "OK" "" }
        else { & $add $e "Ingressado em $DominioEsperado" "FALTA" "atual: $dom" }
    } elseif ($cs) {
        $atual = if ($cs.PartOfDomain) { "dominio $($cs.Domain)" } else { "grupo de trabalho $($cs.Domain)" }
        & $add $e "Situacao atual" "INFO" $atual
    }

    # 6 - Conta admin
    $e = "6. Conta admin"
    $adm = Get-LocalUser -Name "admin" -EA SilentlyContinue
    if (-not $adm) {
        & $add $e "Conta 'admin' existe" "FALTA" ""
    } else {
        & $add $e "Conta 'admin' existe" "OK" $(if ($adm.Enabled) { "habilitada" } else { "desabilitada" })
        if (-not $adm.Enabled) { & $add $e "Conta 'admin' habilitada" "FALTA" "conta desabilitada" }
        $grpAdm = (Get-LocalGroup | Where-Object { $_.SID -match "S-1-5-32-544" }).Name
        $grpUsr = (Get-LocalGroup | Where-Object { $_.SID -match "S-1-5-32-545" }).Name
        $memAdm = @(Get-LocalGroupMember -Group $grpAdm -EA SilentlyContinue | Select-Object -ExpandProperty Name)
        $memUsr = @(Get-LocalGroupMember -Group $grpUsr -EA SilentlyContinue | Select-Object -ExpandProperty Name)
        if ($memAdm -contains "$env:COMPUTERNAME\admin" -or $memAdm -contains "admin") { & $add $e "No grupo Administradores" "OK" "" }
        else { & $add $e "No grupo Administradores" "FALTA" "" }
        if ($memUsr -contains "$env:COMPUTERNAME\admin" -or $memUsr -contains "admin") { & $add $e "Fora do grupo Usuarios" "FALTA" "" }
        else { & $add $e "Fora do grupo Usuarios" "OK" "" }
        if ($adm.PasswordLastSet) { & $add $e "Senha da Zona definida" "OK" "definida em $($adm.PasswordLastSet.ToString('dd/MM/yyyy'))" }
        else { & $add $e "Senha da Zona definida" "FALTA" "conta ainda sem senha (etapa manual)" }
    }

    # 7 - Programas
    $e = "7. Programas"
    $uninst = @(Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
                                 "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
                                 "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -EA SilentlyContinue |
                Where-Object { $_.DisplayName })
    foreach ($p in $Programas) {
        $m = $uninst | Where-Object { $_.DisplayName -match $p.Pattern } | Select-Object -First 1
        if ($m) { & $add $e $p.Name "OK" (("$($m.DisplayName) $($m.DisplayVersion)").Trim()) }
        else { & $add $e $p.Name "FALTA" "nao instalado" }
    }
    $svc = Get-Service -Name "uvnc_service" -EA SilentlyContinue
    if ($svc) {
        if ($svc.Status -eq "Running") {
            & $add $e "UltraVNC: servico rodando" "OK" ""
            try {
                $pids = @(Get-Process -Name "winvnc" -EA SilentlyContinue | Select-Object -ExpandProperty Id)
                $portas = @(Get-NetTCPConnection -State Listen -EA Stop | Where-Object { $pids -contains $_.OwningProcess } |
                            Select-Object -ExpandProperty LocalPort -Unique | Sort-Object)
                if ($portas -contains 8888) { & $add $e "UltraVNC: porta 8888" "OK" "" }
                elseif ($portas.Count -gt 0) { & $add $e "UltraVNC: porta 8888" "AVISO" "escutando em: $($portas -join ', ')" }
                else { & $add $e "UltraVNC: porta 8888" "AVISO" "nenhuma porta encontrada" }
            } catch { & $add $e "UltraVNC: porta 8888" "AVISO" "nao foi possivel consultar as portas" }
        } else { & $add $e "UltraVNC: servico rodando" "FALTA" "servico $($svc.Status)" }
    } elseif ($uninst | Where-Object { $_.DisplayName -match "UltraVNC" }) {
        & $add $e "UltraVNC: servico rodando" "FALTA" "instalado, mas sem o servico uvnc_service"
    }

    # 8 - Certificado
    $e = "8. Certificado"
    foreach ($cp in $CertificadosPadrao) {
        $thumb = ($cp.Thumbprint -replace "\s", "").ToUpper()
        $curto = "$($thumb.Substring(0, 4))...$($thumb.Substring($thumb.Length - 4))"
        if (Test-Path "Cert:\LocalMachine\Root\$thumb") { & $add $e "$($cp.Name) ($curto)" "OK" "em Raiz Confiavel (maquina)" }
        else { & $add $e "$($cp.Name) ($curto)" "FALTA" "nao esta em Raiz Confiavel (maquina)" }
    }
    if ($CertPath -and (Test-Path $CertPath)) {
        $arqs = if ($CertIsDir) { @(Get-ChildItem -Path $CertPath -File | Where-Object { $_.Extension -in ".cer", ".crt" }) } else { @(Get-Item -Path $CertPath) }
        foreach ($a in $arqs) {
            try {
                $x = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($a.FullName)
                if (Test-Path "Cert:\LocalMachine\Root\$($x.Thumbprint)") { & $add $e $a.Name "OK" $x.Subject }
                else { & $add $e $a.Name "FALTA" "nao esta em Raiz Confiavel (maquina)" }
            } catch { & $add $e $a.Name "AVISO" "arquivo nao e um certificado valido" }
        }
    } elseif ($CertificadosPadrao.Count -eq 0) { & $add $e "Certificado" "INFO" "nenhum arquivo/pasta selecionado na GUI" }

    # 9 - Ativacao (Windows e Office)
    $e = "9. Ativacao"
    $estadoLic = { param($s) if ($s -eq 1) { "OK" } elseif ($s -in 2, 3, 6) { "AVISO" } else { "FALTA" } }
    $wl = Get-WindowsLicenseInfo
    if ($wl) {
        & $add $e "Windows" (& $estadoLic $wl.Status) (Get-ResumoLicenca $wl.ChaveParcial $wl.Status $wl.Canal)
    } else {
        & $add $e "Windows" "AVISO" "nao foi possivel ler a licenca"
    }
    $of = Get-OfficeStatus
    if ($of.Licencas.Count -gt 0) {
        foreach ($l in $of.Licencas) {
            & $add $e "Office ($($l.Nome))" (& $estadoLic $l.Status) (Get-ResumoLicenca $l.ChaveParcial $l.Status $l.Canal)
        }
    } elseif ($of.Contas.Count -gt 0) {
        & $add $e "Office" "AVISO" "licenca por conta Microsoft ($($of.Contas[0].Email)); confirme em Arquivo > Conta"
    } elseif ($of.Instalacao.Count -gt 0) {
        & $add $e "Office" "FALTA" "instalado, mas sem licenca registrada"
    } else {
        & $add $e "Office" "INFO" "nao instalado"
    }

    return @($res)
}

function Set-AdminAccount {
    # Decisao do mantenedor: conta sem senha de proposito; o tecnico define a senha da zona depois.
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
    $usersGrp = (Get-LocalGroup | Where-Object { $_.SID -match "S-1-5-32-545" }).Name
    if (-not $usersGrp) { $usersGrp = "Usuarios" }
    $usersMem = Get-LocalGroupMember -Group $usersGrp -EA SilentlyContinue | Select-Object -ExpandProperty Name
    if ($usersMem -contains "$env:COMPUTERNAME\admin" -or $usersMem -contains "admin") {
        Remove-LocalGroupMember -Group $usersGrp -Member "admin" -EA SilentlyContinue
    }
    return $grp
}

function Test-ComputerName {
    param([string]$Name)
    if ($Name.Length -gt 15) { return "Nome excede 15 caracteres (tem $($Name.Length))." }
    if ($Name.Length -lt 1) { return "Nome nao pode ser vazio." }
    if ($Name -match '[\\/:*?"<>|\s]') { return "Nome contem caracteres invalidos (espacos ou \\/:*?`"<>|)." }
    if ($Name -match '^\d+$') { return "Nome nao pode ser composto apenas por numeros." }
    return $null
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
    $corAviso    = $corAmarelo
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
    $btnChaveOffice = & $mkBtn "Chave Office"     72
    $btnAtivar   = & $mkBtn "Ativar Win/Office"   97

    & $mkHeader "CONFIGURAR" 125
    $btnAssist   = & $mkBtn "Assist. Remota"      142
    $btnTestar   = & $mkBtn "Testar Assist."      167
    $btnRDP      = & $mkBtn "Habilitar RDP"       192
    $btnFuso     = & $mkBtn "Fuso Horario"        217
    $btnAdmin    = & $mkBtn "Conta Admin"         242

    & $mkHeader "COMPUTADOR" 270
    $btnRename   = & $mkBtn "Renomear PC"         287
    $btnDominio  = & $mkBtn "Ingresso Dominio"    312

    $botoesLaterais = @($btnInfoPC, $btnChave, $btnChaveOffice, $btnAtivar, $btnAssist, $btnTestar, $btnRDP, $btnFuso, $btnAdmin, $btnRename, $btnDominio)

    $btnSair = New-Object System.Windows.Forms.Button
    $btnSair.Text = "SAIR"
    $btnSair.Font = New-Object System.Drawing.Font("Consolas", 8, [System.Drawing.FontStyle]::Bold)
    $btnSair.BackColor = [System.Drawing.Color]::FromArgb(130, 30, 30)
    $btnSair.ForeColor = $corTexto
    $btnSair.FlatStyle = "Flat"
    $btnSair.FlatAppearance.BorderSize = 0
    $btnSair.Size = New-Object System.Drawing.Size(170, 22)
    $btnSair.Location = New-Object System.Drawing.Point(10, 338)
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
    $txtDomUser.Tag = "usuario"
    $txtDomUser.Add_GotFocus({
        if ($txtDomUser.Text -eq $txtDomUser.Tag) {
            $txtDomUser.Text = ""
            $txtDomUser.ForeColor = $corTexto
        }
    })
    $txtDomUser.Add_LostFocus({
        if ($txtDomUser.Text.Trim() -eq "") {
            $txtDomUser.Text = $txtDomUser.Tag
            $txtDomUser.ForeColor = [System.Drawing.Color]::Gray
        }
    })
    $panelEtapas.Controls.Add($txtDomUser)

    $txtDomPass = New-Object System.Windows.Forms.TextBox
    $txtDomPass.Font = New-Object System.Drawing.Font("Consolas", 8)
    $txtDomPass.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $txtDomPass.ForeColor = [System.Drawing.Color]::Gray
    $txtDomPass.Text = "senha"
    $txtDomPass.Size = New-Object System.Drawing.Size(55, 20)
    $txtDomPass.Location = New-Object System.Drawing.Point(178, $yE)
    $txtDomPass.Tag = "senha"
    $txtDomPass.Add_GotFocus({
        if ($txtDomPass.Text -eq $txtDomPass.Tag) {
            $txtDomPass.Text = ""
            $txtDomPass.ForeColor = $corTexto
            $txtDomPass.UseSystemPasswordChar = $true
        }
    })
    $txtDomPass.Add_LostFocus({
        if ($txtDomPass.Text.Trim() -eq "") {
            $txtDomPass.UseSystemPasswordChar = $false
            $txtDomPass.Text = $txtDomPass.Tag
            $txtDomPass.ForeColor = [System.Drawing.Color]::Gray
        }
    })
    $panelEtapas.Controls.Add($txtDomPass)

    # ----------------------------------------------------------
    # PAINEL PROGRAMAS (direito)
    # ----------------------------------------------------------
    $panelProgs = New-Object System.Windows.Forms.Panel
    $panelProgs.Location = New-Object System.Drawing.Point(461, 38)
    $panelProgs.Size = New-Object System.Drawing.Size(459, 362)
    $panelProgs.BackColor = $corPainel
    $form.Controls.Add($panelProgs)

    # --- MODO CHOCOLATEY (radio) ---
    $rbChoco = New-Object System.Windows.Forms.RadioButton
    $rbChoco.Text = "  INSTALACAO VIA CHOCOLATEY"
    $rbChoco.Font = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Bold)
    $rbChoco.ForeColor = $corAmarelo
    $rbChoco.BackColor = $corPainel
    $rbChoco.Size = New-Object System.Drawing.Size(440, 22)
    $rbChoco.Location = New-Object System.Drawing.Point(5, 5)
    $rbChoco.Checked = $true
    $panelProgs.Controls.Add($rbChoco)

    $rbWinget = New-Object System.Windows.Forms.RadioButton
    $rbWinget.Text = "  INSTALACAO VIA WINGET (Windows 10/11)"
    $rbWinget.Font = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Bold)
    $rbWinget.ForeColor = $corAmarelo
    $rbWinget.BackColor = $corPainel
    $rbWinget.Size = New-Object System.Drawing.Size(440, 22)
    $rbWinget.Location = New-Object System.Drawing.Point(5, 28)
    $panelProgs.Controls.Add($rbWinget)

    $listPrograms = @(
        @{ ChocoId = "Temurin8jre";       WingetId = "EclipseAdoptium.Temurin.8.JRE";      Name = "Java (JRE)";     Extra = ""; Pattern = "Temurin|^Java( |\()" },
        @{ ChocoId = "winrar";            WingetId = "RARLab.WinRAR";                      Name = "WinRAR";          Extra = ""; Pattern = "^WinRAR" },
        @{ ChocoId = "vlc";               WingetId = "VideoLAN.VLC";                       Name = "VLC";             Extra = ""; Pattern = "VLC media player" },
        @{ ChocoId = "FoxitReader";       WingetId = "Foxit.FoxitReader";                  Name = "Foxit Reader";    Extra = ""; Pattern = "Foxit" },
        @{ ChocoId = "pdf24";             WingetId = "geeksoftwareGmbH.PDF24Creator";      Name = "PDF24";           Extra = ""; Pattern = "PDF24" },
        @{ ChocoId = "libreoffice-still"; WingetId = "TheDocumentFoundation.LibreOffice";  Name = "LibreOffice";     Extra = ""; Pattern = "LibreOffice" },
        @{ ChocoId = "GoogleChrome";      WingetId = "Google.Chrome";                      Name = "Google Chrome";   Extra = "--ignore-checksums"; Pattern = "^Google Chrome" },
        @{ ChocoId = "Firefox";           WingetId = "Mozilla.Firefox.pt-BR";              Name = "Firefox";         Extra = ""; Pattern = "Mozilla Firefox" },
        @{ ChocoId = "ultravnc";          WingetId = "uvncbvba.UltraVNC";                  Name = "UltraVNC (GUI)";  Extra = ""; Pattern = "UltraVNC" }
    )

    $cbProgs = @{}
    $yP = 58; $col = 10
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

    # Ajustar yP para a proxima linha completa
    if ($col -eq 230) { $yP += 26 }

    # --- Separador visual ---
    $lblSepProgs = New-Object System.Windows.Forms.Label
    $lblSepProgs.Text = ""
    $lblSepProgs.BorderStyle = "Fixed3D"
    $lblSepProgs.Size = New-Object System.Drawing.Size(430, 2)
    $lblSepProgs.Location = New-Object System.Drawing.Point(10, ($yP + 4))
    $panelProgs.Controls.Add($lblSepProgs)
    $yP += 14

    # --- MODO STANDALONE (radio) ---
    $rbStandalone = New-Object System.Windows.Forms.RadioButton
    $rbStandalone.Text = "  INSTALACAO VIA STANDALONES (pasta local)"
    $rbStandalone.Font = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Bold)
    $rbStandalone.ForeColor = $corAmarelo
    $rbStandalone.BackColor = $corPainel
    $rbStandalone.Size = New-Object System.Drawing.Size(440, 22)
    $rbStandalone.Location = New-Object System.Drawing.Point(5, $yP)
    $panelProgs.Controls.Add($rbStandalone)
    $yP += 26

    $lblStandaloneInfo = New-Object System.Windows.Forms.Label
    $lblStandaloneInfo.Text = "  Selecione a pasta com os .exe ao iniciar"
    $lblStandaloneInfo.Font = New-Object System.Drawing.Font("Consolas", 8)
    $lblStandaloneInfo.ForeColor = [System.Drawing.Color]::Gray
    $lblStandaloneInfo.Size = New-Object System.Drawing.Size(440, 16)
    $lblStandaloneInfo.Location = New-Object System.Drawing.Point(5, $yP)
    $panelProgs.Controls.Add($lblStandaloneInfo)

    $script:standalonePath = $null

    $btnEscolherPasta = New-Object System.Windows.Forms.Button
    $btnEscolherPasta.Text = "Escolher pasta..."
    $btnEscolherPasta.Font = New-Object System.Drawing.Font("Consolas", 8)
    $btnEscolherPasta.BackColor = $corBtnTool
    $btnEscolherPasta.ForeColor = $corTexto
    $btnEscolherPasta.FlatStyle = "Flat"
    $btnEscolherPasta.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(70, 70, 90)
    $btnEscolherPasta.Size = New-Object System.Drawing.Size(130, 24)
    $btnEscolherPasta.Location = New-Object System.Drawing.Point(10, ($yP + 20))
    $btnEscolherPasta.Enabled = $false
    $panelProgs.Controls.Add($btnEscolherPasta)

    $lblPastaSelecionada = New-Object System.Windows.Forms.Label
    $lblPastaSelecionada.Text = ""
    $lblPastaSelecionada.Font = New-Object System.Drawing.Font("Consolas", 7)
    $lblPastaSelecionada.ForeColor = $corOk
    $lblPastaSelecionada.Size = New-Object System.Drawing.Size(300, 16)
    $lblPastaSelecionada.Location = New-Object System.Drawing.Point(145, ($yP + 24))
    $panelProgs.Controls.Add($lblPastaSelecionada)

    # --- INSTALAR CERTIFICADO (Raiz Confiavel, maquina local) ---
    $yC = $yP + 52
    $lblSepCert = New-Object System.Windows.Forms.Label
    $lblSepCert.Text = ""
    $lblSepCert.BorderStyle = "Fixed3D"
    $lblSepCert.Size = New-Object System.Drawing.Size(430, 2)
    $lblSepCert.Location = New-Object System.Drawing.Point(10, $yC)
    $panelProgs.Controls.Add($lblSepCert)

    $cbCert = New-Object System.Windows.Forms.CheckBox
    $cbCert.Text = "  INSTALAR CERTIFICADO (Raiz Confiavel - maquina)"
    $cbCert.Font = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Bold)
    $cbCert.ForeColor = $corAmarelo
    $cbCert.BackColor = $corPainel
    $cbCert.Size = New-Object System.Drawing.Size(445, 22)
    $cbCert.Location = New-Object System.Drawing.Point(5, ($yC + 8))
    $panelProgs.Controls.Add($cbCert)

    $script:certPath = $null
    $script:certIsDir = $false
    $certsPadrao = @(
        @{ Name = "Certificado padrao Semsa"; Thumbprint = "23F4E23C6B21311DF5F2FD3C961C1249CD218675" }
    )

    $mkBtnCert = {
        param([string]$txt, [int]$x)
        $b = New-Object System.Windows.Forms.Button
        $b.Text = $txt
        $b.Font = New-Object System.Drawing.Font("Consolas", 8)
        $b.BackColor = $corBtnTool
        $b.ForeColor = $corTexto
        $b.FlatStyle = "Flat"
        $b.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(70, 70, 90)
        $b.Size = New-Object System.Drawing.Size(130, 24)
        $b.Location = New-Object System.Drawing.Point($x, ($yC + 34))
        $panelProgs.Controls.Add($b)
        return $b
    }
    $btnCertArquivo = & $mkBtnCert "Escolher arquivo..." 10
    $btnCertPasta   = & $mkBtnCert "Escolher pasta..." 145

    $lblCertSelecionado = New-Object System.Windows.Forms.Label
    $lblCertSelecionado.Text = "  Nenhum arquivo/pasta selecionado (.cer/.crt)"
    $lblCertSelecionado.Font = New-Object System.Drawing.Font("Consolas", 7)
    $lblCertSelecionado.ForeColor = [System.Drawing.Color]::Gray
    $lblCertSelecionado.Size = New-Object System.Drawing.Size(440, 16)
    $lblCertSelecionado.Location = New-Object System.Drawing.Point(5, ($yC + 62))
    $panelProgs.Controls.Add($lblCertSelecionado)

    $btnCertArquivo.Add_Click({
        $fd = New-Object System.Windows.Forms.OpenFileDialog
        $fd.Title = "Selecione o certificado (.cer)"
        $fd.Filter = "Certificado (*.cer;*.crt)|*.cer;*.crt|Todos os arquivos (*.*)|*.*"
        if ($fd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $script:certPath = $fd.FileName
            $script:certIsDir = $false
            $lblCertSelecionado.Text = "  Arquivo: $([System.IO.Path]::GetFileName($fd.FileName))"
            $lblCertSelecionado.ForeColor = $corOk
            $cbCert.Checked = $true
        }
    })
    $btnCertPasta.Add_Click({
        $fd = New-Object System.Windows.Forms.FolderBrowserDialog
        $fd.Description = "Selecione a pasta com os certificados (.cer/.crt)"
        $fd.ShowNewFolderButton = $false
        if ($fd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $script:certPath = $fd.SelectedPath
            $script:certIsDir = $true
            $qtd = @(Get-ChildItem -Path $fd.SelectedPath -File | Where-Object { $_.Extension -in '.cer','.crt' }).Count
            $lblCertSelecionado.Text = "  $qtd .cer/.crt encontrado(s)"
            $lblCertSelecionado.ForeColor = if ($qtd -gt 0) { $corOk } else { $corErro }
            $cbCert.Checked = ($qtd -gt 0)
        }
    })

    # --- Eventos de alternancia ---
    $rbChoco.Add_CheckedChanged({
        if ($rbChoco.Checked) {
            foreach ($key in $cbProgs.Keys) { $cbProgs[$key].Enabled = $true }
            $btnEscolherPasta.Enabled = $false
            $lblStandaloneInfo.ForeColor = [System.Drawing.Color]::Gray
        }
    })
    $rbWinget.Add_CheckedChanged({
        if ($rbWinget.Checked) {
            foreach ($key in $cbProgs.Keys) { $cbProgs[$key].Enabled = $true }
            $btnEscolherPasta.Enabled = $false
            $lblStandaloneInfo.ForeColor = [System.Drawing.Color]::Gray
        }
    })
    $rbStandalone.Add_CheckedChanged({
        if ($rbStandalone.Checked) {
            foreach ($key in $cbProgs.Keys) { $cbProgs[$key].Enabled = $false }
            $btnEscolherPasta.Enabled = $true
            $lblStandaloneInfo.ForeColor = $corTexto
        }
    })
    $btnEscolherPasta.Add_Click({
        $fd = New-Object System.Windows.Forms.FolderBrowserDialog
        $fd.Description = "Selecione a pasta com os instaladores (.exe)"
        $fd.ShowNewFolderButton = $false
        if ($fd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $script:standalonePath = $fd.SelectedPath
            $exes = (Get-ChildItem -Path $fd.SelectedPath -Filter "*.exe" -File).Count
            $lblPastaSelecionada.Text = "$exes .exe encontrado(s)"
            $lblPastaSelecionada.ForeColor = if ($exes -gt 0) { $corOk } else { $corErro }
        }
    })

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
    $btnIniciar.Size = New-Object System.Drawing.Size(352, 40)
    $btnIniciar.Location = New-Object System.Drawing.Point(208, 407)
    $form.Controls.Add($btnIniciar)

    $btnVerificar = New-Object System.Windows.Forms.Button
    $btnVerificar.Text = "VERIFICAR PADRONIZACAO"
    $btnVerificar.Font = New-Object System.Drawing.Font("Consolas", 11, [System.Drawing.FontStyle]::Bold)
    $btnVerificar.BackColor = [System.Drawing.Color]::FromArgb(40, 110, 100)
    $btnVerificar.ForeColor = $corTexto
    $btnVerificar.FlatStyle = "Flat"
    $btnVerificar.FlatAppearance.BorderSize = 0
    $btnVerificar.Size = New-Object System.Drawing.Size(354, 40)
    $btnVerificar.Location = New-Object System.Drawing.Point(566, 407)
    $form.Controls.Add($btnVerificar)
    $botoesLaterais = @($botoesLaterais) + $btnVerificar

    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(208, 452)
    $progressBar.Size = New-Object System.Drawing.Size(712, 18)
    $progressBar.Style = "Continuous"
    $progressBar.Minimum = 0
    $progressBar.Maximum = 1
    $progressBar.Value = 0
    $form.Controls.Add($progressBar)

    $lblProgresso = New-Object System.Windows.Forms.Label
    $lblProgresso.Text = ""
    $lblProgresso.Font = New-Object System.Drawing.Font("Consolas", 8)
    $lblProgresso.ForeColor = $corAmarelo
    $lblProgresso.Size = New-Object System.Drawing.Size(195, 63)
    $lblProgresso.Location = New-Object System.Drawing.Point(10, 407)
    $form.Controls.Add($lblProgresso)

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

    # Habilita Assistencia Remota (registro + firewall + servicos) - unico ponto de manutencao
    $habilitarAssistencia = {
        Set-ItemProperty "HKLM:\System\CurrentControlSet\Control\Terminal Server" "fDenyTSConnections" 0 -EA SilentlyContinue
        Set-ItemProperty "HKLM:\System\CurrentControlSet\Control\Terminal Server" "fAllowToGetHelp" 1 -EA SilentlyContinue
        Remove-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" "fAllowToGetHelp" -EA SilentlyContinue
        Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" "fAllowToGetHelp" 1 -EA SilentlyContinue
        Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance" "fAllowToGetHelp" 1 -EA SilentlyContinue
        Enable-NetFirewallRule -Group "@FirewallAPI.dll,-28752" -EA SilentlyContinue
        Get-NetFirewallRule -EA SilentlyContinue | Where-Object { $_.Name -like "RemoteAssistance*" } | Enable-NetFirewallRule -EA SilentlyContinue
        foreach ($sn in @("TermService","SessionEnv","UmRdpService","RemoteRegistry")) {
            $s = Get-Service -Name $sn -EA SilentlyContinue
            if ($s) {
                if ($s.StartType -eq "Disabled") { Set-Service $sn -StartupType Automatic -EA SilentlyContinue }
                if ($s.Status -ne "Running")     { Start-Service $sn -EA SilentlyContinue }
            }
        }
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
            $key = (Get-CimInstance -ClassName SoftwareLicensingService -EA Stop).OA3xOriginalProductKey
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
            $wl = Get-WindowsLicenseInfo
            if ($wl) {
                $corW = if ($wl.Status -eq 1) { $corOk } elseif ($wl.Status -in 2, 3, 6) { $corAviso } else { $corErro }
                & $log "" $corTexto
                & $log "  RESUMO  : $(Get-ResumoLicenca $wl.ChaveParcial $wl.Status $wl.Canal)" $corW
                & $log "  Tipo    : $($wl.Canal)  ($($wl.Descricao))" $corTexto
                & $log "  Licenca : $($wl.StatusNome)" $corW
                & $log "  Final da chave em uso: $($wl.ChaveParcial)" $corTexto
                if ($wl.KmsHost) { & $log "  Servidor KMS: $($wl.KmsHost)" $corTexto }
                if ($wl.DiasRestantes -gt 0) { & $log "  Dias restantes (tolerancia/renovacao): $($wl.DiasRestantes)" $corTexto }
                if ($wl.BiosChaveOem) { & $log "  BIOS: tem chave OEM embutida (final $($wl.BiosChaveOem.Substring($wl.BiosChaveOem.Length - 5)))" $corTexto }
                else { & $log "  BIOS: sem chave OEM embutida." $corTexto }
            }
        } catch {
            & $log "  [ERRO] $($_.Exception.Message)" $corErro
        }
        $btnChave.Enabled = $true
    })

    $btnChaveOffice.Add_Click({
        $btnChaveOffice.Enabled = $false
        & $sepLog "STATUS DO OFFICE"
        & $log "  Consultando licenciamento do Office..." $corTexto
        try {
            $of = Get-OfficeStatus
            if ($of.Instalacao.Count -eq 0 -and $of.Licencas.Count -eq 0 -and $of.Contas.Count -eq 0) {
                & $log "  [AVISO] Office nao encontrado neste computador." $corAviso
            } else {
                foreach ($i in $of.Instalacao) { & $log "  Instalado: $i" $corTexto }
                if ($of.Contas.Count -gt 0) {
                    & $log "  Contas Microsoft conectadas ao Office:" $corTexto
                    foreach ($c in $of.Contas) { & $log "    $($c.Usuario) -> $($c.Email)" $corTexto }
                }
                if ($of.Licencas.Count -eq 0) {
                    if ($of.Contas.Count -gt 0) {
                        & $log "  [AVISO] Sem licenca por chave. Licenca por conta (Microsoft 365): confirme em Arquivo > Conta." $corAviso
                    } else {
                        & $log "  [AVISO] Office instalado, mas sem licenca/chave registrada (nunca ativado)." $corAviso
                        & $log "  Use 'Ativar Win/Office' ou ative pelo proprio Office." $corAviso
                    }
                }
                foreach ($l in $of.Licencas) {
                    $cor = switch ($l.Status) { 1 { $corOk } { $_ -in 2, 3, 6 } { $corAviso } default { $corErro } }
                    & $log "" $corTexto
                    & $log "  Produto : $($l.Nome)" $corTexto
                    & $log "  RESUMO  : $(Get-ResumoLicenca $l.ChaveParcial $l.Status $l.Canal)" $cor
                    & $log "  Status  : $($l.StatusNome)" $cor
                    & $log "  Chave   : XXXXX-XXXXX-XXXXX-XXXXX-$($l.ChaveParcial)  (so os 5 ultimos caracteres ficam no Office)" $corTexto
                    & $log "  Tipo    : $($l.Canal)  ($($l.Descricao))" $corTexto
                    if ($l.Status -ne 1) {
                        $mot = if ($l.Motivo) { " - $($l.Motivo)" } else { "" }
                        & $log "  Motivo  : $($l.CodigoMotivo)$mot" $cor
                    }
                    if ($l.DiasRestantes -gt 0) { & $log "  Dias restantes (tolerancia/renovacao): $($l.DiasRestantes)" $corTexto }
                }
                $ativos = @($of.Licencas | Where-Object { $_.Status -eq 1 }).Count
                & $log "" $corTexto
                if ($ativos -gt 0) {
                    & $log "  RESULTADO: Office ATIVO." $corOk
                } elseif ($of.Contas.Count -gt 0) {
                    & $log "  RESULTADO: sem licenca por chave ativa; ha conta conectada -- verifique em Arquivo > Conta." $corAviso
                } elseif ($of.Licencas.Count -gt 0) {
                    & $log "  RESULTADO: Office COM PROBLEMA (nenhuma licenca ativa)." $corErro
                }
            }
        } catch {
            & $log "  [ERRO] $($_.Exception.Message)" $corErro
        }
        $btnChaveOffice.Enabled = $true
    })

    $btnVerificar.Add_Click({
        $btnVerificar.Enabled = $false
        $btnIniciar.Enabled = $false
        & $sepLog "VERIFICAR PADRONIZACAO"
        & $log "  Verificando todas as etapas (somente leitura)..." $corTexto
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        try {
            $itens = Get-PadronizacaoStatus -NomeEsperado $txtNome.Text.Trim() -DominioEsperado $txtDominio.Text.Trim() `
                -Programas $listPrograms -CertPath "$($script:certPath)" -CertIsDir ([bool]$script:certIsDir) `
                -CertificadosPadrao $certsPadrao
            $etapaAtual = ""
            foreach ($it in $itens) {
                if ($it.Etapa -ne $etapaAtual) {
                    $etapaAtual = $it.Etapa
                    & $log "" $corTexto
                    & $log "  $etapaAtual" $corAmarelo
                }
                $marca = switch ($it.Estado) { "OK" { "[OK]   " } "FALTA" { "[FALTA]" } "AVISO" { "[AVISO]" } default { "[INFO] " } }
                $cor = switch ($it.Estado) { "OK" { $corOk } "FALTA" { $corErro } "AVISO" { $corAviso } default { $corTexto } }
                $det = if ($it.Detalhe) { " -- $($it.Detalhe)" } else { "" }
                & $log "    $marca $($it.Item)$det" $cor
            }
            $nOk = @($itens | Where-Object { $_.Estado -eq "OK" }).Count
            $faltam = @($itens | Where-Object { $_.Estado -eq "FALTA" })
            $nAviso = @($itens | Where-Object { $_.Estado -eq "AVISO" }).Count
            & $log "" $corTexto
            & $log "  ================================================" $corDestaque
            & $log "  RESUMO: $nOk OK | $($faltam.Count) FALTAM | $nAviso AVISOS" $(if ($faltam.Count -eq 0) { $corOk } else { $corAviso })
            if ($faltam.Count -gt 0) {
                & $log "  Pendentes:" $corAviso
                foreach ($f in $faltam) { & $log "    - $($f.Etapa): $($f.Item)" $corAviso }
            } else {
                & $log "  Nenhuma pendencia encontrada." $corOk
            }
            & $log "  ================================================" $corDestaque
        } catch {
            & $log "  [ERRO] $($_.Exception.Message)" $corErro
        }
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
        $btnVerificar.Enabled = $true
        $btnIniciar.Enabled = $true
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
            & $habilitarAssistencia
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
            $grp = Set-AdminAccount
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
                $erroNome = Test-ComputerName -Name $novoNome
                if ($erroNome) {
                    & $sepLog "RENOMEAR COMPUTADOR"
                    & $log "  [ERRO] $erroNome" $corErro
                } else {
                    & $sepLog "RENOMEAR COMPUTADOR"
                    try {
                        Rename-Computer -NewName $novoNome -Force -EA Stop
                        $script:guiNeedsRestart = $true
                        & $log "  [OK] Renomeado para '$novoNome'. Reinicio necessario." $corOk
                    } catch { & $log "  [ERRO] $($_.Exception.Message)" $corErro }
                }
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
        $botoesLaterais | ForEach-Object { $_.Enabled = $false }

        & $log "" $corInfo
        & $log "  ================================================" $corDestaque
        & $log "   INICIANDO PADRONIZACAO AUTOMATICA" $corAmarelo
        & $log "  ================================================" $corDestaque

        $totalEtapas = 0
        if ($cbEtapas["fuso"].Checked) { $totalEtapas++ }
        if ($cbEtapas["assist"].Checked) { $totalEtapas++ }
        if ($cbEtapas["rdp"].Checked) { $totalEtapas++ }
        if ($txtNome.Text.Trim() -ne "") { $totalEtapas++ }
        if ($txtDominio.Text.Trim() -ne "") { $totalEtapas++ }
        if ($cbEtapas["admin"].Checked) { $totalEtapas++ }
        if ($cbEtapas["progs"].Checked) {
            if ($rbChoco.Checked -or $rbWinget.Checked) {
                $totalEtapas += @($listPrograms | Where-Object { $cbProgs[$_.ChocoId].Checked }).Count
            } else {
                $totalEtapas++
            }
        }
        if ($cbCert.Checked) { $totalEtapas++ }
        $progressBar.Maximum = [Math]::Max($totalEtapas, 1) * 100
        $progressBar.Value = 0

        # Etapa 1 - Fuso
        if ($cbEtapas["fuso"].Checked) {
            & $log "  [1] Configurando fuso horario Manaus..." $corInfo
            try {
                Set-TimeZone -Id "SA Western Standard Time" -EA Stop
                & $log "      [OK] Fuso configurado." $corOk
            } catch { & $log "      [ERRO] $($_.Exception.Message)" $corErro }
            $progressBar.Value = [Math]::Min($progressBar.Value + 100, $progressBar.Maximum)
            [System.Windows.Forms.Application]::DoEvents()
        }

        # Etapa 2 - Assistencia Remota
        if ($cbEtapas["assist"].Checked) {
            & $log "  [2] Habilitando Assistencia Remota..." $corInfo
            try {
                & $habilitarAssistencia
                & $log "      [OK] Assistencia Remota habilitada." $corOk
            } catch { & $log "      [ERRO] $($_.Exception.Message)" $corErro }
            $progressBar.Value = [Math]::Min($progressBar.Value + 100, $progressBar.Maximum)
            [System.Windows.Forms.Application]::DoEvents()
        }

        # Etapa 3 - RDP
        if ($cbEtapas["rdp"].Checked) {
            & $log "  [3] Habilitando RDP..." $corInfo
            try {
                Set-ItemProperty "HKLM:\System\CurrentControlSet\Control\Terminal Server" "fDenyTSConnections" 0 -EA Stop
                & $log "      [OK] RDP habilitado." $corOk
            } catch { & $log "      [ERRO] $($_.Exception.Message)" $corErro }
            $progressBar.Value = [Math]::Min($progressBar.Value + 100, $progressBar.Maximum)
            [System.Windows.Forms.Application]::DoEvents()
        }

        # Etapa 4 - Nome do computador
        if ($txtNome.Text.Trim() -ne "") {
            $nomePC = $txtNome.Text.Trim()
            $erroNome = Test-ComputerName -Name $nomePC
            if ($erroNome) {
                & $log "  [4] $erroNome" $corErro
            } else {
                & $log "  [4] Renomeando para '$nomePC'..." $corInfo
                try {
                    Rename-Computer -NewName $nomePC -Force -EA Stop
                    $script:guiNeedsRestart = $true
                    & $log "      [OK] Renomeado. Reinicializacao necessaria." $corOk
                } catch { & $log "      [ERRO] $($_.Exception.Message)" $corErro }
            }
            $progressBar.Value = [Math]::Min($progressBar.Value + 100, $progressBar.Maximum)
            [System.Windows.Forms.Application]::DoEvents()
        }

        # Etapa 5 - Dominio
        $domVal = $txtDominio.Text.Trim()
        if ($domVal -ne "") {
            $domUsr = if ($txtDomUser.Text -eq $txtDomUser.Tag) { "" } else { $txtDomUser.Text.Trim() }
            $domPas = if ($txtDomPass.Text -eq $txtDomPass.Tag) { "" } else { $txtDomPass.Text }
            if ($domUsr -eq "" -or $domPas -eq "") {
                & $log "  [5] [ERRO] Usuario e senha do dominio sao obrigatorios." $corErro
            } else {
                & $log "  [5] Ingressando no dominio '$domVal'..." $corInfo
                try {
                    $sp   = ConvertTo-SecureString $domPas -AsPlainText -Force
                    $cred = New-Object System.Management.Automation.PSCredential($domUsr, $sp)
                    Add-Computer -DomainName $domVal -Credential $cred -Force -EA Stop
                    $script:guiNeedsRestart = $true
                    & $log "      [OK] Ingressou no dominio. Reinicializacao necessaria." $corOk
                } catch { & $log "      [ERRO] $($_.Exception.Message)" $corErro }
            }
            $progressBar.Value = [Math]::Min($progressBar.Value + 100, $progressBar.Maximum)
            [System.Windows.Forms.Application]::DoEvents()
        }

        # Etapa 6 - Conta admin
        if ($cbEtapas["admin"].Checked) {
            & $log "  [6] Criando conta admin..." $corInfo
            try {
                $grp = Set-AdminAccount
                & $log "      [OK] Conta admin configurada no grupo '$grp'." $corOk
            } catch { & $log "      [ERRO] $($_.Exception.Message)" $corErro }
            $progressBar.Value = [Math]::Min($progressBar.Value + 100, $progressBar.Maximum)
            [System.Windows.Forms.Application]::DoEvents()
        }

        # Etapa 7 - Programas
        if ($cbEtapas["progs"].Checked) {
            & $log "" $corInfo

            # Executa choco/winget com stdout em arquivo temporario; mostra % no rotulo e na barra
            $runPkg = {
                param([string]$exe, [string]$pkgArgs, [string]$nome)
                $tmpFile = [System.IO.Path]::GetTempFileName()
                $exitCode = $null
                $base = $progressBar.Value
                $cron = [System.Diagnostics.Stopwatch]::StartNew()
                $pos = 0
                $pctAtual = -1
                $ultimaLinha = ""
                try {
                    $proc = Start-Process -FilePath $exe -ArgumentList $pkgArgs `
                        -RedirectStandardOutput $tmpFile -NoNewWindow -PassThru
                    $null = $proc.Handle
                    do {
                        $terminou = $proc.HasExited
                        $texto = ""
                        try {
                            $fs = [System.IO.FileStream]::new($tmpFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
                            $sr = New-Object System.IO.StreamReader($fs)
                            $texto = $sr.ReadToEnd(); $sr.Dispose(); $fs.Dispose()
                        } catch {}
                        if ($texto.Length -gt $pos) {
                            $novo = $texto.Substring($pos)
                            if (-not $terminou) {
                                $ult = $novo.LastIndexOfAny([char[]]"`r`n")
                                if ($ult -lt 0) { $novo = "" } else { $novo = $novo.Substring(0, $ult + 1) }
                            }
                            $pos += $novo.Length
                            foreach ($seg in ($novo -split "[\r\n]+")) {
                                $t = $seg.Trim()
                                if (-not $t) { continue }
                                if ($t -match 'Progress:\s*(.*?)\s*(\d{1,3})%') { $pctAtual = [int]$Matches[2]; continue }
                                if ($t -match '^Progress:') { continue }
                                if ($t.Length -le 1) { continue }
                                if ($t.Contains([string][char]0x2588) -or $t.Contains([string][char]0x2592)) { continue }
                                if ($t -eq $ultimaLinha) { continue }
                                $ultimaLinha = $t
                                & $log "        $t" $corTexto
                            }
                        }
                        $tempo = $cron.Elapsed.ToString('mm\:ss')
                        if ($pctAtual -ge 100) {
                            $lblProgresso.Text = "$nome`ninstalando... ($tempo)"
                        } elseif ($pctAtual -ge 0) {
                            $lblProgresso.Text = "$nome`nbaixando $pctAtual% ($tempo)"
                        } else {
                            $lblProgresso.Text = "$nome`naguarde... ($tempo)"
                        }
                        $progressBar.Value = [Math]::Min($base + [Math]::Max([Math]::Min($pctAtual, 99), 0), $progressBar.Maximum)
                        [System.Windows.Forms.Application]::DoEvents()
                        if (-not $terminou) { Start-Sleep -Milliseconds 300 }
                    } while (-not $terminou)
                    $proc.WaitForExit()
                    $exitCode = [int]$proc.ExitCode
                } finally {
                    $progressBar.Value = $base
                    Remove-Item $tmpFile -EA SilentlyContinue
                }
                return $exitCode
            }

            if ($rbStandalone.Checked) {
                # ---- MODO STANDALONE ----
                & $log "  [7] Instalando programas via Standalones (pasta local)..." $corInfo
                if (-not $script:standalonePath -or -not (Test-Path $script:standalonePath)) {
                    $fd = New-Object System.Windows.Forms.FolderBrowserDialog
                    $fd.Description = "Selecione a pasta com os instaladores (.exe)"
                    $fd.ShowNewFolderButton = $false
                    if ($fd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                        $script:standalonePath = $fd.SelectedPath
                    } else {
                        & $log "      [AVISO] Selecao cancelada. Etapa ignorada." $corAviso
                        $script:standalonePath = $null
                    }
                }
                if ($script:standalonePath -and (Test-Path $script:standalonePath)) {
                    $certs = Get-ChildItem -Path $script:standalonePath -File | Where-Object { $_.Extension -in '.cer','.crt','.pem' }
                    if ($certs.Count -gt 0) {
                        & $log "      $($certs.Count) certificado(s) encontrado(s) -- instalando em Raiz Confiavel (LocalMachine)..." $corInfo
                        foreach ($certFile in $certs) {
                            try {
                                Import-Certificate -FilePath $certFile.FullName -CertStoreLocation Cert:\LocalMachine\Root | Out-Null
                                & $log "      [OK] Certificado: $($certFile.Name)" $corOk
                            } catch {
                                & $log "      [ERRO] Certificado $($certFile.Name): $($_.Exception.Message)" $corErro
                            }
                        }
                    }
                    $instaladores = Get-ChildItem -Path $script:standalonePath -Filter "*.exe" -File | Sort-Object Name
                    if ($instaladores.Count -eq 0 -and $certs.Count -eq 0) {
                        & $log "      [ERRO] Nenhum .exe ou certificado encontrado em: $($script:standalonePath)" $corErro
                    } elseif ($instaladores.Count -gt 0) {
                        & $log "      Pasta: $($script:standalonePath)" $corTexto
                        & $log "      $($instaladores.Count) instalador(es) encontrado(s)" $corTexto
                        $progressBar.Maximum = $progressBar.Value + ($instaladores.Count * 100)
                        $idxSt = 0
                        foreach ($inst in $instaladores) {
                            $idxSt++
                            & $log "      [$idxSt/$($instaladores.Count)] Executando $($inst.Name)..." $corInfo
                            [System.Windows.Forms.Application]::DoEvents()
                            try {
                                $proc = Start-Process -FilePath $inst.FullName -PassThru
                                $terminou = $proc.WaitForExit(600000)
                                if ($terminou) {
                                    if ($proc.ExitCode -eq 0) {
                                        & $log "      [OK] $($inst.Name)" $corOk
                                    } else {
                                        & $log "      [AVISO] $($inst.Name) (cod: $($proc.ExitCode))" $corAviso
                                    }
                                } else {
                                    & $log "      [AVISO] $($inst.Name) excedeu 10min -- seguindo para o proximo..." $corAviso
                                }
                            } catch {
                                & $log "      [ERRO] $($inst.Name): $($_.Exception.Message)" $corErro
                            }
                            $progressBar.Value = [Math]::Min($progressBar.Value + 100, $progressBar.Maximum)
                            [System.Windows.Forms.Application]::DoEvents()
                        }
                    }
                }
            } elseif ($rbWinget.Checked -and (Get-Command winget -EA SilentlyContinue)) {
            # ---- MODO WINGET ----
            & $log "  [7] Instalando programas via Winget..." $corInfo

            $wgBase = "install --exact --source winget --accept-package-agreements --accept-source-agreements"
            $selecionados = @($listPrograms | Where-Object { $cbProgs[$_.ChocoId].Checked -and $_.ChocoId -ne "ultravnc" })
            $vncSelecionado = $cbProgs["ultravnc"].Checked
            $totalWg = $selecionados.Count + [int]$vncSelecionado

            $tratarWinget = {
                param([string]$nome, $codigo)
                if ($codigo -eq 0) {
                    & $log "      [OK] $nome" $corOk
                } elseif ($codigo -eq -1978335189 -or $codigo -eq -1978335135) {
                    & $log "      [OK] $nome (ja instalado)" $corOk
                } elseif ($codigo -eq -1978334967) {
                    $script:guiNeedsRestart = $true
                    & $log "      [OK] $nome (reinicializacao necessaria para concluir)" $corOk
                } else {
                    & $log ("      [ERRO] {0} (cod: {1} / 0x{2:X8})" -f $nome, $codigo, $codigo) $corErro
                }
            }

            $idxWg = 0
            foreach ($p in $selecionados) {
                $idxWg++
                & $log "      Instalando $($p.Name)..." $corInfo
                $codigo = & $runPkg "winget" "$wgBase --id $($p.WingetId) --silent --disable-interactivity" "[$idxWg/$totalWg] $($p.Name)"
                & $tratarWinget $p.Name $codigo
                $progressBar.Value = [Math]::Min($progressBar.Value + 100, $progressBar.Maximum)
                [System.Windows.Forms.Application]::DoEvents()
            }

            if ($vncSelecionado) {
                $idxWg++
                & $log "" $corInfo
                & $log "      Abrindo instalador do UltraVNC (interativo)..." $corAviso
                & $log "      Configure e finalize o instalador para continuar." $corAviso
                $codigo = & $runPkg "winget" "$wgBase --id uvncbvba.UltraVNC --interactive" "[$idxWg/$totalWg] UltraVNC (GUI)"
                & $tratarWinget "UltraVNC" $codigo
                $progressBar.Value = [Math]::Min($progressBar.Value + 100, $progressBar.Maximum)
                [System.Windows.Forms.Application]::DoEvents()
            }
            $lblProgresso.Text = ""
            } else {
            # ---- MODO CHOCOLATEY (original; tambem e o fallback do winget) ----
            if ($rbWinget.Checked) {
                & $log "  [7] [AVISO] Winget nao encontrado (requer Windows 10 1809+/11 com 'Instalador de Aplicativo')." $corAviso
                & $log "      Usando Chocolatey como alternativa." $corAviso
            }
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

                $selecionados = @($selecionados)
                $totalCh = $selecionados.Count + [int]$vncSelecionado
                $idxCh = 0

                foreach ($p in $selecionados) {
                    $idxCh++
                    & $log "      Instalando $($p.Name)..." $corInfo
                    $argStr = "install $($p.ChocoId) -y"
                    if ($p.Extra) { $argStr += " $($p.Extra)" }
                    $codigo = & $runPkg "choco" $argStr "[$idxCh/$totalCh] $($p.Name)"
                    if ($codigo -eq 0) {
                        & $log "      [OK] $($p.Name)" $corOk
                    } else {
                        & $log "      [ERRO] $($p.Name) (cod: $codigo)" $corErro
                    }
                    $progressBar.Value = [Math]::Min($progressBar.Value + 100, $progressBar.Maximum)
                    [System.Windows.Forms.Application]::DoEvents()
                }

                if ($vncSelecionado) {
                    $idxCh++
                    & $log "" $corInfo
                    & $log "      Abrindo instalador do UltraVNC (interativo)..." $corAviso
                    & $log "      Configure e finalize o instalador para continuar." $corAviso
                    $codigo = & $runPkg "choco" 'install ultravnc --override-arguments --install-arguments="/SP- /NORESTART" -y' "[$idxCh/$totalCh] UltraVNC (GUI)"
                    if ($codigo -eq 0) {
                        & $log "      [OK] UltraVNC instalado." $corOk
                    } else {
                        & $log "      [ERRO] UltraVNC falhou (cod: $codigo)." $corErro
                    }
                    $progressBar.Value = [Math]::Min($progressBar.Value + 100, $progressBar.Maximum)
                    [System.Windows.Forms.Application]::DoEvents()
                }
            }
            $lblProgresso.Text = ""
            }
        }

        # Etapa 8 - Certificado (Raiz Confiavel, maquina local)
        if ($cbCert.Checked) {
            & $log "" $corInfo
            & $log "  [8] Instalando certificado(s) em Raiz Confiavel (maquina local)..." $corInfo
            if (-not $script:certPath -or -not (Test-Path $script:certPath)) {
                & $log "      [AVISO] Nenhum arquivo/pasta de certificado selecionado. Etapa ignorada." $corAviso
            } else {
                if ($script:certIsDir) {
                    $arqsCert = @(Get-ChildItem -Path $script:certPath -File | Where-Object { $_.Extension -in '.cer','.crt' })
                } else {
                    $arqsCert = @(Get-Item -Path $script:certPath)
                }
                if ($arqsCert.Count -eq 0) {
                    & $log "      [ERRO] Nenhum .cer/.crt encontrado em: $($script:certPath)" $corErro
                }
                foreach ($arqCert in $arqsCert) {
                    try {
                        $x509 = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($arqCert.FullName)
                        $saidaCert = & certutil.exe -addstore -f Root $arqCert.FullName 2>&1
                        if ($LASTEXITCODE -ne 0) { throw "certutil cod $LASTEXITCODE - $(($saidaCert | Select-Object -Last 1))" }
                        if (Test-Path "Cert:\LocalMachine\Root\$($x509.Thumbprint)") {
                            & $log "      [OK] $($arqCert.Name) -- $($x509.Subject)" $corOk
                        } else {
                            throw "certificado nao encontrado no repositorio apos a importacao"
                        }
                    } catch {
                        & $log "      [ERRO] $($arqCert.Name): $($_.Exception.Message)" $corErro
                    }
                }
            }
            $progressBar.Value = [Math]::Min($progressBar.Value + 100, $progressBar.Maximum)
            [System.Windows.Forms.Application]::DoEvents()
        }

        if ($script:standalonePath) {
            $vncIni = Join-Path $script:standalonePath "ultravnc.ini"
            if (Test-Path $vncIni) {
                & $log "" $corInfo
                & $log "  [POS] Configurando UltraVNC..." $corInfo
                $vncDir = @("${env:ProgramFiles}\uvnc bvba\UltraVNC",
                            "${env:ProgramFiles(x86)}\uvnc bvba\UltraVNC") |
                          Where-Object { Test-Path $_ } | Select-Object -First 1
                if ($vncDir) {
                    try {
                        Stop-Service uvnc_service -Force -EA SilentlyContinue
                        Start-Sleep -Seconds 2
                        Copy-Item $vncIni "$vncDir\ultravnc.ini" -Force
                        Start-Service uvnc_service -EA SilentlyContinue
                        & $log "      [OK] ultravnc.ini aplicado e servico reiniciado." $corOk
                    } catch {
                        & $log "      [ERRO] UltraVNC config: $($_.Exception.Message)" $corErro
                    }
                } else {
                    & $log "      [AVISO] Pasta do UltraVNC nao encontrada -- ini nao aplicado." $corAviso
                }
            }
        }

        & $log "" $corInfo
        & $log "  ================================================" $corAviso
        & $log "  ATENCAO -- ETAPA MANUAL RESTANTE:" $corAviso
        & $log "  [1] Senha admin: colocar de acordo com a Zona" $corAviso
        & $log "  ================================================" $corAviso

        $script:guiConcluido = $true
        $btnIniciar.Text = "CONCLUIDO -- Clique para fechar"
        $btnIniciar.BackColor = [System.Drawing.Color]::FromArgb(0, 110, 0)
        $btnIniciar.Enabled = $true
        $botoesLaterais | ForEach-Object { $_.Enabled = $true }

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

# Verificar se o script esta sendo executado como administrador
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(
        "Este script nao esta sendo executado como Administrador.`n`nAlgumas funcoes podem falhar (configuracoes de registro, firewall, servicos).`n`nFeche e reabra o PowerShell como Administrador para funcionalidade completa.",
        "Aviso -- Sem privilegios administrativos",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    ) | Out-Null
}

# Por ultimo, abrimos a GUI principal
Show-PadronizacaoGUI

