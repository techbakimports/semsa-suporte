
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

function Set-AdminAccount {
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

    $botoesLaterais = @($btnInfoPC, $btnChave, $btnAtivar, $btnAssist, $btnTestar, $btnRDP, $btnFuso, $btnAdmin, $btnRename, $btnDominio)

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

    # --- Eventos de alternancia ---
    $rbChoco.Add_CheckedChanged({
        if ($rbChoco.Checked) {
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

    # Habilita Assistencia Remota (registro + firewall + servicos) - unico ponto de manutencao
    $habilitarAssistencia = {
        Set-ItemProperty "HKLM:\System\CurrentControlSet\Control\Terminal Server" "fDenyTSConnections" 0 -EA SilentlyContinue
        Set-ItemProperty "HKLM:\System\CurrentControlSet\Control\Terminal Server" "fAllowToGetHelp" 1 -EA SilentlyContinue
        Remove-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" "fAllowToGetHelp" -EA SilentlyContinue
        Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" "fAllowToGetHelp" 1 -EA SilentlyContinue
        Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance" "fAllowToGetHelp" 1 -EA SilentlyContinue
        Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -EA SilentlyContinue
        Enable-NetFirewallRule -DisplayGroup "Remote Assistance" -EA SilentlyContinue
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
                & $habilitarAssistencia
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
        }

        # Etapa 6 - Conta admin
        if ($cbEtapas["admin"].Checked) {
            & $log "  [6] Criando conta admin..." $corInfo
            try {
                $grp = Set-AdminAccount
                & $log "      [OK] Conta admin configurada no grupo '$grp'." $corOk
            } catch { & $log "      [ERRO] $($_.Exception.Message)" $corErro }
        }

        # Etapa 7 - Programas
        if ($cbEtapas["progs"].Checked) {
            & $log "" $corInfo

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
                        & $log "      $($certs.Count) certificado(s) encontrado(s) — instalando em Raiz Confiavel (LocalMachine)..." $corInfo
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
                        $progressBar.Maximum = $instaladores.Count
                        $progressBar.Value = 0
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
                                    & $log "      [AVISO] $($inst.Name) excedeu 10min — seguindo para o proximo..." $corAviso
                                }
                            } catch {
                                & $log "      [ERRO] $($inst.Name): $($_.Exception.Message)" $corErro
                            }
                            $progressBar.Value = [Math]::Min($progressBar.Value + 1, $progressBar.Maximum)
                            [System.Windows.Forms.Application]::DoEvents()
                        }
                    }
                }
            } else {
            # ---- MODO CHOCOLATEY (original) ----
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
                    & $log "      [AVISO] Pasta do UltraVNC nao encontrada — ini nao aplicado." $corAviso
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

