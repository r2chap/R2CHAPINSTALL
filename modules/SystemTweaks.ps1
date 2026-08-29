# ==========================================
# MODULE : SYSTEM TWEAKS (Optimisations Windows)
# Fichier : modules/SystemTweaks.ps1
# Basé sur l'interface WinUtil (Chris Titus Tech)
# ==========================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ------------------------------------------
# HELPER : LOGGING
# ------------------------------------------
function Write-TweakLog {
    param(
        [System.Windows.Forms.RichTextBox]$LogBox,
        [string]$Message,
        [System.Drawing.Color]$Color
    )
    if ($LogBox -and -not $LogBox.IsDisposed) {
        $LogBox.SelectionStart = $LogBox.TextLength
        $LogBox.SelectionLength = 0
        $LogBox.SelectionColor = $Color
        $LogBox.AppendText("[$([DateTime]::Now.ToString('HH:mm:ss'))] $Message`n")
        $LogBox.ScrollToCaret()
    }
}

# ------------------------------------------
# DÉFINITION DES OPTIMISATIONS (TWEAKS)
# ------------------------------------------

# 1. ESSENTIAL TWEAKS (Cases pré-cochées basées sur l'image 2)
$script:EssentialTweaks = @(
    @{ ID = "ActivityHistory"; Label = "Activity History - Disable"; Checked = $true; Action = {
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableActivityFeed" -Value 0 -Force -ErrorAction SilentlyContinue
    }},
    @{ ID = "BitLocker"; Label = "BitLocker - Disable"; Checked = $false; Action = {
        Disable-BitLocker -MountPoint "C:" -ErrorAction SilentlyContinue
    }},
    @{ ID = "ConsumerFeatures"; Label = "ConsumerFeatures - Disable"; Checked = $true; Action = {
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsConsumerFeatures" -Value 1 -Force -ErrorAction SilentlyContinue
    }},
    @{ ID = "DeliveryOptimization"; Label = "Delivery Optimization - Disable"; Checked = $true; Action = {
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" -Name "DODownloadMode" -Value 0 -Force -ErrorAction SilentlyContinue
    }},
    @{ ID = "DiskCleanup"; Label = "Disk Cleanup - Run"; Checked = $false; Action = {
        Start-Process cleanmgr.exe -ArgumentList "/sagerun:1" -NoNewWindow -Wait -ErrorAction SilentlyContinue
    }},
    @{ ID = "EndTaskRightClick"; Label = "End Task With Right Click - Enable"; Checked = $true; Action = {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarEndTask" -Value 1 -Force -ErrorAction SilentlyContinue
    }},
    @{ ID = "FolderDiscovery"; Label = "File Explorer Automatic Folder Discovery - Disable"; Checked = $true; Action = {
        Set-ItemProperty -Path "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags\AllFolders\Shell" -Name "FolderType" -Value "NotSpecified" -Force -ErrorAction SilentlyContinue
    }},
    @{ ID = "Hibernation"; Label = "Hibernation - Disable"; Checked = $false; Action = {
        powercfg /hibernate off
    }},
    @{ ID = "LocationTracking"; Label = "Location Tracking - Disable"; Checked = $true; Action = {
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Name "Value" -Value "Deny" -Force -ErrorAction SilentlyContinue
    }},
    @{ ID = "StoreRecommendedSearch"; Label = "Microsoft Store Recommended Search Results - Disable"; Checked = $true; Action = {
        Set-ItemProperty -Path "HKCU:\Software\Policies\Microsoft\Windows\Explorer" -Name "DisableSearchBoxSuggestions" -Value 1 -Force -ErrorAction SilentlyContinue
    }},
    @{ ID = "PreventCompanionApps"; Label = "Prevent Device Companion Apps"; Checked = $false; Action = {
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Settings" -Name "DisableDeviceInstallHints" -Value 1 -Force -ErrorAction SilentlyContinue
    }},
    @{ ID = "RestorePoint"; Label = "Restore Point - Create"; Checked = $true; Action = {
        Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description "R2CHAP_PreTweakRestore" -RestorePointType "MODIFY_SETTINGS" -ErrorAction SilentlyContinue
    }},
    @{ ID = "ServicesManual"; Label = "Services - Set to Manual"; Checked = $true; Action = {
        @("DiagTrack", "sysmain", "MapsBroker") | ForEach-Object { Set-Service -Name $_ -StartupType Manual -ErrorAction SilentlyContinue }
    }},
    @{ ID = "StartPreviousLayout"; Label = "Start Menu Previous Layout - Enable"; Checked = $true; Action = {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_Layout" -Value 0 -Force -ErrorAction SilentlyContinue
    }},
    @{ ID = "Telemetry"; Label = "Telemetry - Disable"; Checked = $true; Action = {
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0 -Force -ErrorAction SilentlyContinue
        Stop-Service -Name "DiagTrack" -ErrorAction SilentlyContinue
        Set-Service -Name "DiagTrack" -StartupType Disabled -ErrorAction SilentlyContinue
    }},
    @{ ID = "TempFiles"; Label = "Temporary Files - Remove"; Checked = $true; Action = {
        Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
    }},
    @{ ID = "Widgets"; Label = "Widgets - Remove"; Checked = $true; Action = {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value 0 -Force -ErrorAction SilentlyContinue
    }},
    @{ ID = "WPBT"; Label = "Windows Platform Binary Table (WPBT) - Disable"; Checked = $true; Action = {
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Executive" -Name "DisableWPBT" -Value 1 -Force -ErrorAction SilentlyContinue
    }}
)

# 2. ADVANCED TWEAKS
$script:AdvancedTweaks = @(
    @{ ID = "AdobeURLBlock"; Label = "Adobe URL Block List - Enable"; Checked = $false; Action = {} },
    @{ ID = "BackgroundApps"; Label = "Background Apps - Disable"; Checked = $false; Action = {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" -Name "GlobalUserDisabled" -Value 1 -Force -ErrorAction SilentlyContinue
    }},
    @{ ID = "BraveDebloat"; Label = "Brave Browser - Debloat"; Checked = $false; Action = {} },
    @{ ID = "DateTimeUTC"; Label = "Date & Time - Set Time to UTC"; Checked = $false; Action = {
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" -Name "RealTimeIsUniversal" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    }},
    @{ ID = "DisableReservedStorage"; Label = "Disable Reserved Storage"; Checked = $false; Action = {
        Set-WindowsReservedStorageState -State Disabled -ErrorAction SilentlyContinue
    }},
    @{ ID = "ExplorerHomeGallery"; Label = "File Explorer Home and Gallery - Disable"; Checked = $false; Action = {} },
    @{ ID = "IPv6Disable"; Label = "IPv6 - Disable"; Checked = $false; Action = {
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" -Name "DisabledComponents" -Value 255 -Force -ErrorAction SilentlyContinue
    }},
    @{ ID = "IPv6SetIPv4Preferred"; Label = "IPv6 - Set IPv4 as Preferred"; Checked = $false; Action = {
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" -Name "DisabledComponents" -Value 32 -Force -ErrorAction SilentlyContinue
    }},
    @{ ID = "EdgeDebloat"; Label = "Microsoft Edge - Debloat"; Checked = $false; Action = {} },
    @{ ID = "EdgeRemove"; Label = "Microsoft Edge - Remove"; Checked = $false; Action = {} }
)

# 3. CUSTOMIZE PREFERENCES (Interrupteurs / Toggle Switches de l'image 1)
$script:CustomizePreferences = @(
    @{ Label = "BSOD Verbose Mode"; State = $true },
    @{ Label = "Dark Theme for Windows"; State = $true },
    @{ Label = "Enable Long Paths"; State = $true },
    @{ Label = "File Explorer File Extensions"; State = $true },
    @{ Label = "File Explorer Hidden Files"; State = $true },
    @{ Label = "Game Mode"; State = $true },
    @{ Label = "Lock Screen - Disable"; State = $false },
    @{ Label = "Logon Screen Acrylic Blur"; State = $true },
    @{ Label = "Logon Verbose Mode"; State = $false },
    @{ Label = "Microsoft Outlook New Version"; State = $true },
    @{ Label = "Mouse Acceleration"; State = $true },
    @{ Label = "Num Lock on Startup"; State = $true },
    @{ Label = "S0 Sleep Network Connectivity"; State = $true },
    @{ Label = "S3 Sleep"; State = $false },
    @{ Label = "Scrollbars Always Visible"; State = $false },
    @{ Label = "Settings Home Page"; State = $true },
    @{ Label = "Start Menu Bing Search"; State = $false },
    @{ Label = "Start Menu Recommendations"; State = $false },
    @{ Label = "Sticky Keys"; State = $false },
    @{ Label = "System Tray Battery Percentage"; State = $false },
    @{ Label = "Taskbar Centered Icons"; State = $false },
    @{ Label = "Taskbar Search Icon"; State = $false }
)

# ------------------------------------------
# MOTEUR D'EXÉCUTION DES TWEAKS
# ------------------------------------------
function Invoke-SystemTweaksExecution {
    param(
        [array]$CheckBoxControls,
        [System.Windows.Forms.RichTextBox]$LogBox,
        [System.Windows.Forms.ProgressBar]$ProgressBar,
        [System.Windows.Forms.Form]$ParentForm
    )

    $selectedTweaks = $CheckBoxControls | Where-Object { $_.Checked -eq $true }

    if ($selectedTweaks.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Veuillez sélectionner au moins une optimisation à exécuter.", "Aucune sélection", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    Write-TweakLog -LogBox $LogBox -Message "==========================================" -Color ([System.Drawing.Color]::Blue)
    Write-TweakLog -LogBox $LogBox -Message "DÉBUT DE L'APPLICATION DES OPTIMISATIONS..." -Color ([System.Drawing.Color]::Blue)

    if ($ProgressBar) {
        $ProgressBar.Value = 0
        $ProgressBar.Maximum = $selectedTweaks.Count
    }

    $currentIndex = 0

    foreach ($chk in $selectedTweaks) {
        $tweakData = $chk.Tag
        $currentIndex++

        Write-TweakLog -LogBox $LogBox -Message "Application : $($tweakData.Label)..." -Color ([System.Drawing.Color]::DarkSlateGray)
        if ($ParentForm) { $ParentForm.Refresh() }

        try {
            & $tweakData.Action
            Write-TweakLog -LogBox $LogBox -Message "SUCCÈS : $($tweakData.Label)" -Color ([System.Drawing.Color]::ForestGreen)
        } catch {
            Write-TweakLog -LogBox $LogBox -Message "ERREUR : $($tweakData.Label) -> $($_.Exception.Message)" -Color ([System.Drawing.Color]::Red)
        }

        if ($ProgressBar) { $ProgressBar.Value = $currentIndex }
        if ($ParentForm) { $ParentForm.Refresh() }
    }

    Write-TweakLog -LogBox $LogBox -Message "==========================================" -Color ([System.Drawing.Color]::ForestGreen)
    Write-TweakLog -LogBox $LogBox -Message "TOUTES LES OPTIMISATIONS SÉLECTIONNÉES ONT ÉTÉ APPLIQUÉES !" -Color ([System.Drawing.Color]::ForestGreen)

    [System.Windows.Forms.MessageBox]::Show("Les optimisations système sélectionnées ont été appliquées avec succès.", "Optimisation Terminée", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
}

# ------------------------------------------
# CONSTRUCTION DE L'ONGLET SYSTEM TWEAKS
# ------------------------------------------
function Build-TabSystemTweaks {
    param(
        [System.Windows.Forms.TabPage]$TargetTab,
        [System.Windows.Forms.Form]$ParentForm,
        [System.Drawing.Color]$BgColor
    )

    $TargetTab.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#12181F") # Fond sombre type WinUtil

    $fontTitle = New-Object System.Drawing.Font("Consolas", 11, [System.Drawing.FontStyle]::Bold)
    $fontItem  = New-Object System.Drawing.Font("Segoe UI", 8.5, [System.Drawing.FontStyle]::Regular)
    $fontBtn   = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)

    $allCheckBoxes = @()

    # Console Log
    $logBox = New-Object System.Windows.Forms.RichTextBox
    $logBox.Location = New-Object System.Drawing.Point(10, 310)
    $logBox.Size = New-Object System.Drawing.Size(840, 115)
    $logBox.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#0D1117")
    $logBox.ForeColor = [System.Drawing.Color]::White
    $logBox.ReadOnly = $true
    $logBox.Font = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Regular)
    $TargetTab.Controls.Add($logBox)

    # Barre de progression
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(10, 435)
    $progressBar.Size = New-Object System.Drawing.Size(840, 20)
    $progressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Continuous
    $TargetTab.Controls.Add($progressBar)

    # --------------------------------------------------
    # COLONNE GAUCHE : ESSENTIAL & ADVANCED TWEAKS
    # --------------------------------------------------
    $panelLeft = New-Object System.Windows.Forms.Panel
    $panelLeft.Location = New-Object System.Drawing.Point(10, 10)
    $panelLeft.Size = New-Object System.Drawing.Size(430, 255)
    $panelLeft.AutoScroll = $true
    $TargetTab.Controls.Add($panelLeft)

    # 1. Essential Tweaks Header
    $lblEssential = New-Object System.Windows.Forms.Label
    $lblEssential.Text = "Essential Tweaks"
    $lblEssential.Font = $fontTitle
    $lblEssential.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#58A6FF")
    $lblEssential.Size = New-Object System.Drawing.Size(400, 20)
    $lblEssential.Location = New-Object System.Drawing.Point(0, 0)
    $panelLeft.Controls.Add($lblEssential)

    $posY = 22
    foreach ($item in $script:EssentialTweaks) {
        $chk = New-Object System.Windows.Forms.CheckBox
        $chk.Text = $item.Label
        $chk.Checked = $item.Checked
        $chk.Font = $fontItem
        $chk.ForeColor = [System.Drawing.Color]::White
        $chk.AutoSize = $true
        $chk.Location = New-Object System.Drawing.Point(5, $posY)
        $chk.Tag = $item
        $panelLeft.Controls.Add($chk)
        $allCheckBoxes += $chk
        $posY += 20
    }

    # 2. Advanced Tweaks Header
    $posY += 10
    $lblAdvanced = New-Object System.Windows.Forms.Label
    $lblAdvanced.Text = "Advanced Tweaks - CAUTION"
    $lblAdvanced.Font = $fontTitle
    $lblAdvanced.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#58A6FF")
    $lblAdvanced.Size = New-Object System.Drawing.Size(400, 20)
    $lblAdvanced.Location = New-Object System.Drawing.Point(0, $posY)
    $panelLeft.Controls.Add($lblAdvanced)

    $posY += 22
    foreach ($item in $script:AdvancedTweaks) {
        $chk = New-Object System.Windows.Forms.CheckBox
        $chk.Text = $item.Label
        $chk.Checked = $item.Checked
        $chk.Font = $fontItem
        $chk.ForeColor = [System.Drawing.Color]::White
        $chk.AutoSize = $true
        $chk.Location = New-Object System.Drawing.Point(5, $posY)
        $chk.Tag = $item
        $panelLeft.Controls.Add($chk)
        $allCheckBoxes += $chk
        $posY += 20
    }

    # --------------------------------------------------
    # COLONNE DROITE : CUSTOMIZE PREFERENCES
    # --------------------------------------------------
    $panelRight = New-Object System.Windows.Forms.Panel
    $panelRight.Location = New-Object System.Drawing.Point(450, 10)
    $panelRight.Size = New-Object System.Drawing.Size(400, 255)
    $panelRight.AutoScroll = $true
    $TargetTab.Controls.Add($panelRight)

    $lblPrefs = New-Object System.Windows.Forms.Label
    $lblPrefs.Text = "Customize Preferences"
    $lblPrefs.Font = $fontTitle
    $lblPrefs.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#58A6FF")
    $lblPrefs.Size = New-Object System.Drawing.Size(380, 20)
    $lblPrefs.Location = New-Object System.Drawing.Point(0, 0)
    $panelRight.Controls.Add($lblPrefs)

    $posYRight = 22
    foreach ($pref in $script:CustomizePreferences) {
        $chk = New-Object System.Windows.Forms.CheckBox
        $chk.Text = $pref.Label
        $chk.Checked = $pref.State
        $chk.Font = $fontItem
        $chk.ForeColor = [System.Drawing.Color]::White
        $chk.AutoSize = $true
        $chk.Location = New-Object System.Drawing.Point(5, $posYRight)
        $panelRight.Controls.Add($chk)
        $posYRight += 20
    }

    # --------------------------------------------------
    # BOUTONS D'ACTION (RUN TWEAKS / UNDO)
    # --------------------------------------------------
    $btnRun = New-Object System.Windows.Forms.Button
    $btnRun.Text = "Run Tweaks"
    $btnRun.Font = $fontBtn
    $btnRun.Size = New-Object System.Drawing.Size(180, 30)
    $btnRun.Location = New-Object System.Drawing.Point(10, 272)
    $btnRun.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#1F6FEB")
    $btnRun.ForeColor = [System.Drawing.Color]::White
    $btnRun.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnRun.Cursor = [System.Windows.Forms.Cursors]::Hand
    
    $chkList = $allCheckBoxes
    $lBox = $logBox
    $pBar = $progressBar
    $pForm = $ParentForm

    $btnRun.Add_Click({
        Invoke-SystemTweaksExecution -CheckBoxControls $chkList -LogBox $lBox -ProgressBar $pBar -ParentForm $pForm
    })
    $TargetTab.Controls.Add($btnRun)

    $btnUndo = New-Object System.Windows.Forms.Button
    $btnUndo.Text = "Undo Selected Tweaks"
    $btnUndo.Font = $fontBtn
    $btnUndo.Size = New-Object System.Drawing.Size(180, 30)
    $btnUndo.Location = New-Object System.Drawing.Point(200, 272)
    $btnUndo.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#21262D")
    $btnUndo.ForeColor = [System.Drawing.Color]::White
    $btnUndo.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnUndo.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnUndo.Add_Click({
        Write-TweakLog -LogBox $lBox -Message "Annulation non configurée." -Color ([System.Drawing.Color]::Orange)
    })
    $TargetTab.Controls.Add($btnUndo)
}