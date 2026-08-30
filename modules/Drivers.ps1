# ==========================================
# MODULE : DRIVERS (Pilotes Nomades & Diagnostic)
# Fichier : modules/Drivers.ps1
# Version : v1.9 (Aligné sur Charte Sombre & Write-Log Global)
# ==========================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic

# ------------------------------------------
# HELPER : EXECUTION ASYNCHRONE ET SECURISEE
# ------------------------------------------
function Invoke-ExecutableWithLog {
    param(
        [string]$ExePath,
        [string]$Arguments,
        [System.Drawing.Color]$TextColor = ([System.Drawing.ColorTranslator]::FromHtml("#F1F4F4"))
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $ExePath
    $psi.Arguments = $Arguments
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi

    # Redirection asynchrone du flux Standard Output
    $outEvent = Register-ObjectEvent -InputObject $process -EventName "OutputDataReceived" -Action {
        if (-not [string]::IsNullOrWhiteSpace($Event.SourceEventArgs.Data)) {
            Write-Log -Message "[DRIVERS] $($Event.SourceEventArgs.Data)" -Color $Event.MessageData.Color
        }
    } -MessageData @{ Color = $TextColor }

    # Redirection asynchrone du flux Standard Error
    $errEvent = Register-ObjectEvent -InputObject $process -EventName "ErrorDataReceived" -Action {
        if (-not [string]::IsNullOrWhiteSpace($Event.SourceEventArgs.Data)) {
            Write-Log -Message "[DRIVERS] $($Event.SourceEventArgs.Data)" -Color ([System.Drawing.Color]::OrangeRed)
        }
    }

    try {
        $null = $process.Start()
        $process.BeginOutputReadLine()
        $process.BeginErrorReadLine()

        while (-not $process.HasExited) {
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 50
        }

        $process.WaitForExit()
        return $process.ExitCode
    } catch {
        Write-Log -Message "[DRIVERS] ERREUR d'exécution : $($_.Exception.Message)" -Color ([System.Drawing.Color]::Red)
        return -1
    } finally {
        Unregister-Event -SourceIdentifier $outEvent.Name -ErrorAction SilentlyContinue
        Unregister-Event -SourceIdentifier $errEvent.Name -ErrorAction SilentlyContinue
        $process.Dispose()
    }
}

# ------------------------------------------
# HELPER : DÉTECTION SYSNATIVE (64-bit)
# ------------------------------------------
function Get-SystemExecutable {
    param([string]$ExeName)

    $sysNativePath = Join-Path $env:SystemRoot "SysNative\$ExeName"
    $system32Path  = Join-Path $env:SystemRoot "System32\$ExeName"

    if (Test-Path $sysNativePath) {
        return $sysNativePath
    } elseif (Test-Path $system32Path) {
        return $system32Path
    }
    return $ExeName
}

# ------------------------------------------
# HELPER : CALCUL DE LA RACINE R2CHAP & DOSSIERS
# ------------------------------------------
function Get-R2ChapBasePath {
    $ScriptDir = $PSScriptRoot
    if (-not $ScriptDir) {
        if ($MyInvocation.MyCommand.Path) {
            $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
        } else {
            $ScriptDir = Get-Location
        }
    }

    $CurrentDir = Get-Item $ScriptDir
    while ($CurrentDir -and $CurrentDir.Name -ne "R2CHAPINSTALL" -and $CurrentDir.Parent) {
        $CurrentDir = $CurrentDir.Parent
    }

    if ($CurrentDir -and $CurrentDir.Name -eq "R2CHAPINSTALL") { 
        return $CurrentDir.FullName 
    } else { 
        return $ScriptDir 
    }
}

function Get-R2ChapDriversPath {
    param([string]$SubFolder = "")

    $RootDir = Get-R2ChapBasePath
    $DriversBaseDir = Join-Path $RootDir "Drivers"

    if (-not (Test-Path $DriversBaseDir)) {
        New-Item -ItemType Directory -Path $DriversBaseDir -Force | Out-Null
    }

    if (-not [string]::IsNullOrWhiteSpace($SubFolder)) {
        $TargetPath = Join-Path $DriversBaseDir $SubFolder
        if (-not (Test-Path $TargetPath)) {
            New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null
        }
        return $TargetPath
    }

    return $DriversBaseDir
}

# ------------------------------------------
# ACTIONS DU SYSTÈME
# ------------------------------------------

function Open-DeviceManager {
    Write-Log -Message "[DRIVERS] ACTION : Ouverture du Gestionnaire de périphériques..." -Color ([System.Drawing.ColorTranslator]::FromHtml("#2CFF05"))
    try {
        Start-Process "devmgmt.msc"
    } catch {
        Write-Log -Message "[DRIVERS] ERREUR : $($_.Exception.Message)" -Color ([System.Drawing.Color]::Red)
    }
}

# 1. SAUVEGARDE EN TEMPS RÉEL (PC ➔ USB) VIA DISM
function Export-SystemDrivers {
    param([System.Windows.Forms.Form]$ParentForm)
    
    $defaultFolderName = "$($env:COMPUTERNAME)_$(Get-Date -Format 'yyyy-MM-dd')"
    
    $folderName = [Microsoft.VisualBasic.Interaction]::InputBox(
        "Entrez un nom pour le dossier de sauvegarde des pilotes :",
        "Sauvegarde des Pilotes PC ➔ USB",
        $defaultFolderName
    )

    if ([string]::IsNullOrWhiteSpace($folderName)) {
        Write-Log -Message "[DRIVERS] Exportation annulée par l'utilisateur." -Color ([System.Drawing.Color]::Orange)
        return
    }

    $folderName = $folderName -replace '[\\/:*?"<>|]', '_'
    $TargetFolder = Get-R2ChapDriversPath -SubFolder $folderName

    Write-Log -Message "[DRIVERS] ==========================================" -Color ([System.Drawing.ColorTranslator]::FromHtml("#2CFF05"))
    Write-Log -Message "[DRIVERS] ACTION : Sauvegarde des pilotes système via DISM..." -Color ([System.Drawing.ColorTranslator]::FromHtml("#2CFF05"))
    Write-Log -Message "[DRIVERS] Dossier cible : $TargetFolder" -Color ([System.Drawing.ColorTranslator]::FromHtml("#F1F4F4"))

    $dismExe = Get-SystemExecutable "dism.exe"

    try {
        $exitCode = Invoke-ExecutableWithLog -ExePath $dismExe -Arguments "/online /export-driver /destination:`"$TargetFolder`"" -TextColor ([System.Drawing.ColorTranslator]::FromHtml("#F1F4F4"))

        if ($exitCode -eq 0) {
            $exportedFiles = Get-ChildItem -Path $TargetFolder -Recurse -Filter "*.inf" -ErrorAction SilentlyContinue
            Write-Log -Message "[DRIVERS] SUCCÈS : Exportation terminée ! $($exportedFiles.Count) pilote(s) sauvegardé(s)." -Color ([System.Drawing.ColorTranslator]::FromHtml("#2CFF05"))
        } else {
            Write-Log -Message "[DRIVERS] ÉCHEC DISM (Code $exitCode). Vérifiez les droits administrateur." -Color ([System.Drawing.Color]::Red)
        }
    } catch {
        Write-Log -Message "[DRIVERS] ERREUR d'exportation : $($_.Exception.Message)" -Color ([System.Drawing.Color]::Red)
    }
}

# 2. RESTAURATION / INSTALLATION MULTI-MÉTHODES (USB ➔ PC)
function Import-SystemDriversFromUSB {
    param([System.Windows.Forms.Form]$ParentForm)
    
    $baseDriversFolder = Get-R2ChapDriversPath

    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = "Sélectionnez le dossier contenant les pilotes (.inf/.cat) à installer"
    $folderBrowser.SelectedPath = $baseDriversFolder
    $folderBrowser.ShowNewFolderButton = $false

    $dialogResult = $folderBrowser.ShowDialog()

    if ($dialogResult -ne [System.Windows.Forms.DialogResult]::OK -or [string]::IsNullOrWhiteSpace($folderBrowser.SelectedPath)) {
        Write-Log -Message "[DRIVERS] Restauration annulée par l'utilisateur." -Color ([System.Drawing.Color]::Orange)
        return
    }

    $SelectedFolder = $folderBrowser.SelectedPath

    Write-Log -Message "[DRIVERS] ==========================================" -Color ([System.Drawing.ColorTranslator]::FromHtml("#2CFF05"))
    Write-Log -Message "[DRIVERS] ACTION : Recherche des packages de pilotes (.INF) dans le dossier..." -Color ([System.Drawing.ColorTranslator]::FromHtml("#2CFF05"))
    Write-Log -Message "[DRIVERS] Source : $SelectedFolder" -Color ([System.Drawing.ColorTranslator]::FromHtml("#F1F4F4"))

    $infFiles = Get-ChildItem -Path $SelectedFolder -Recurse -Filter "*.inf" -ErrorAction SilentlyContinue

    if (-not $infFiles -or $infFiles.Count -eq 0) {
        Write-Log -Message "[DRIVERS] ERREUR : Aucun fichier .inf trouvé dans ce dossier." -Color ([System.Drawing.Color]::Red)
        return
    }

    Write-Log -Message "[DRIVERS] Trouvé : $($infFiles.Count) fichier(s) .inf." -Color ([System.Drawing.ColorTranslator]::FromHtml("#F1F4F4"))

    # Méthode 1 : PNPUtil global
    $pnpExe = Get-SystemExecutable "pnputil.exe"
    Write-Log -Message "[DRIVERS] Lancement de PNPUtil en mode global..." -Color ([System.Drawing.ColorTranslator]::FromHtml("#F1F4F4"))

    $exitCode = Invoke-ExecutableWithLog -ExePath $pnpExe -Arguments "/add-driver `"$SelectedFolder\*.inf`" /subdirs /install" -TextColor ([System.Drawing.ColorTranslator]::FromHtml("#2CFF05"))

    if ($exitCode -eq 0) {
        Write-Log -Message "[DRIVERS] SUCCÈS : Installation globale terminée avec succès !" -Color ([System.Drawing.ColorTranslator]::FromHtml("#2CFF05"))
        return
    }

    # Fallback : Fichier par fichier
    Write-Log -Message "[DRIVERS] Passage en mode installation individuelle par fichier .INF..." -Color ([System.Drawing.Color]::Orange)

    $successCount = 0
    $failCount = 0
    $currentIndex = 0

    foreach ($file in $infFiles) {
        $currentIndex++
        Write-Log -Message "[DRIVERS] [$currentIndex/$($infFiles.Count)] Installation : $($file.Name)..." -Color ([System.Drawing.ColorTranslator]::FromHtml("#2CFF05"))

        $res = Invoke-ExecutableWithLog -ExePath $pnpExe -Arguments "/add-driver `"$($file.FullName)`" /install" -TextColor ([System.Drawing.ColorTranslator]::FromHtml("#F1F4F4"))

        if ($res -eq 0 -or $res -eq 3010) {
            $successCount++
        } else {
            $failCount++
        }
    }

    Write-Log -Message "[DRIVERS] --------------------------------------------------" -Color ([System.Drawing.ColorTranslator]::FromHtml("#2CFF05"))
    Write-Log -Message "[DRIVERS] FIN DU TRAITEMENT : $successCount installé(s) / $failCount échec(s) ou ignoré(s)." -Color ([System.Drawing.ColorTranslator]::FromHtml("#2CFF05"))
}

function Open-DriversDirectory {
    $path = Get-R2ChapDriversPath
    Write-Log -Message "[DRIVERS] ACTION : Ouverture de l'explorateur ($path)" -Color ([System.Drawing.ColorTranslator]::FromHtml("#2CFF05"))
    try {
        Start-Process "explorer.exe" -ArgumentList "`"$path`""
    } catch {
        Write-Log -Message "[DRIVERS] ERREUR : $($_.Exception.Message)" -Color ([System.Drawing.Color]::Red)
    }
}

function Start-HWInfo {
    $rootDir = Get-R2ChapBasePath
    $exePath = Join-Path $rootDir "apps\HWinfo\HWiNFO64.exe"

    Write-Log -Message "[DRIVERS] ACTION : Lancement de HWiNFO64..." -Color ([System.Drawing.ColorTranslator]::FromHtml("#2CFF05"))
    
    if (Test-Path $exePath) {
        try { Start-Process $exePath } catch { Write-Log -Message "[DRIVERS] ERREUR : $($_.Exception.Message)" -Color ([System.Drawing.Color]::Red) }
    } else {
        Write-Log -Message "[DRIVERS] ERREUR : Fichier introuvable ($exePath)" -Color ([System.Drawing.Color]::Red)
    }
}

function Start-FirefoxPortable {
    $rootDir = Get-R2ChapBasePath
    $exePath = Join-Path $rootDir "apps\FirefoxPortable\FirefoxPortable.exe"

    Write-Log -Message "[DRIVERS] ACTION : Lancement de Firefox Portable..." -Color ([System.Drawing.ColorTranslator]::FromHtml("#2CFF05"))

    if (Test-Path $exePath) {
        try { Start-Process $exePath } catch { Write-Log -Message "[DRIVERS] ERREUR : $($_.Exception.Message)" -Color ([System.Drawing.Color]::Red) }
    } else {
        Write-Log -Message "[DRIVERS] ERREUR : Fichier introuvable ($exePath)" -Color ([System.Drawing.Color]::Red)
    }
}

# 3. NETTOYAGE EXPRESS
function Clear-TempAndDownloads {
    param([System.Windows.Forms.Form]$ParentForm)

    $confirm = [System.Windows.Forms.MessageBox]::Show(
        "Le nettoyage express va fermer les navigateurs Web et supprimer le contenu des dossiers Temp et Téléchargements.`n`nSouhaitez-vous continuer ?",
        "Confirmation du nettoyage",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )

    if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) {
        Write-Log -Message "[DRIVERS] Nettoyage annulé par l'utilisateur." -Color ([System.Drawing.Color]::Orange)
        return
    }

    Write-Log -Message "[DRIVERS] ==========================================" -Color ([System.Drawing.ColorTranslator]::FromHtml("#2CFF05"))
    Write-Log -Message "[DRIVERS] ACTION : Démarrage du nettoyage express..." -Color ([System.Drawing.ColorTranslator]::FromHtml("#2CFF05"))

    $browsers = @("chrome", "msedge", "firefox", "brave", "opera")
    foreach ($proc in $browsers) {
        $runningProcs = Get-Process -Name $proc -ErrorAction SilentlyContinue
        if ($runningProcs) {
            Stop-Process -Name $proc -Force -ErrorAction SilentlyContinue
            Write-Log -Message "[DRIVERS] Processus '$proc' fermé." -Color ([System.Drawing.Color]::Orange)
        }
    }

    Start-Sleep -Milliseconds 300

    $userProfile = [Environment]::GetFolderPath("UserProfile")
    $userDownloads = Join-Path $userProfile "Downloads"
    $userTemp      = [System.IO.Path]::GetTempPath()
    $winTemp       = Join-Path $env:SystemRoot "Temp"

    $foldersToClean = @(
        @{ Name = "Téléchargements ($env:USERNAME)"; Path = $userDownloads },
        @{ Name = "Temp Utilisateur"; Path = $userTemp },
        @{ Name = "Temp Windows"; Path = $winTemp }
    )

    $deletedCount = 0
    $skippedCount = 0

    foreach ($item in $foldersToClean) {
        $targetPath = $item.Path
        Write-Log -Message "[DRIVERS] --- Nettoyage : $($item.Name) ---" -Color ([System.Drawing.ColorTranslator]::FromHtml("#F1F4F4"))

        if (Test-Path $targetPath) {
            $elements = Get-ChildItem -Path $targetPath -ErrorAction SilentlyContinue

            if (-not $elements -or $elements.Count -eq 0) {
                Write-Log -Message "[DRIVERS] Aucun fichier à supprimer ou dossier déjà vide." -Color ([System.Drawing.Color]::Gray)
                continue
            }

            foreach ($el in $elements) {
                try {
                    Remove-Item -Path $el.FullName -Recurse -Force -ErrorAction Stop
                    $deletedCount++
                    Write-Log -Message "[DRIVERS] Supprimé : $($el.Name)" -Color ([System.Drawing.ColorTranslator]::FromHtml("#2CFF05"))
                } catch {
                    $skippedCount++
                    Write-Log -Message "[DRIVERS] Ignoré (Verrouillé/Refusé) : $($el.Name)" -Color ([System.Drawing.Color]::Gray)
                }
            }
        } else {
            Write-Log -Message "[DRIVERS] Dossier introuvable : $targetPath" -Color ([System.Drawing.Color]::Gray)
        }
    }

    Write-Log -Message "[DRIVERS] --------------------------------------------------" -Color ([System.Drawing.ColorTranslator]::FromHtml("#2CFF05"))
    Write-Log -Message "[DRIVERS] SUCCÈS : Nettoyage express terminé !" -Color ([System.Drawing.ColorTranslator]::FromHtml("#2CFF05"))
    Write-Log -Message "[DRIVERS] Bilan : $deletedCount élément(s) supprimé(s), $skippedCount verrouillé(s) ignoré(s)." -Color ([System.Drawing.ColorTranslator]::FromHtml("#F1F4F4"))
}

# ------------------------------------------
# CONSTRUCTION DE L'ONGLET DRIVERS
# ------------------------------------------
function Build-TabDrivers {
    param(
        [System.Windows.Forms.TabPage]$TargetTab,
        [System.Windows.Forms.Form]$ParentForm,
        [System.Drawing.Color]$BgColor
    )

    # PALETTE DE COULEURS DISTINCTIVES
    $textColor   = [System.Drawing.ColorTranslator]::FromHtml("#F1F4F4")
    $darkBg      = [System.Drawing.ColorTranslator]::FromHtml("#141A19")
    
    # Couleurs des 3 actions distinctes
    $btnColorDev = [System.Drawing.ColorTranslator]::FromHtml("#0A3468") # Bleu sombre
    $btnColorExp = [System.Drawing.ColorTranslator]::FromHtml("#953489") # Magenta / Violet
    $btnColorImp = [System.Drawing.ColorTranslator]::FromHtml("#A40BF2") # Violet néon

    $TargetTab.BackColor = $BgColor

    $emojiFontBtn  = New-Object System.Drawing.Font("Segoe UI Emoji", 8.5, [System.Drawing.FontStyle]::Bold)
    $emojiFontCard = New-Object System.Drawing.Font("Segoe UI Emoji", 15)

    Write-Log -Message "Module Pilotes chargé." -Color $textColor

    # Actions du haut
    $panelActions = New-Object System.Windows.Forms.GroupBox
    $panelActions.Text = " Actions USB & Système "
    $panelActions.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
    $panelActions.ForeColor = $textColor
    $panelActions.Location = New-Object System.Drawing.Point(10, 10)
    $panelActions.Size = New-Object System.Drawing.Size(840, 75)
    $TargetTab.Controls.Add($panelActions)

    # Bouton 1 : Gestionnaire de périphériques (Bleu)
    $btnScan = New-Object System.Windows.Forms.Button
    $btnScan.Text = "🔍 Gestionnaire périphérique"
    $btnScan.Font = $emojiFontBtn
    $btnScan.Size = New-Object System.Drawing.Size(250, 35)
    $btnScan.Location = New-Object System.Drawing.Point(15, 25)
    $btnScan.BackColor = $btnColorDev
    $btnScan.ForeColor = $textColor
    $btnScan.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnScan.FlatAppearance.BorderSize = 0
    $btnScan.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnScan.Add_Click({ Open-DeviceManager })
    $panelActions.Controls.Add($btnScan)

    # Bouton 2 : Sauvegarde (PC ➔ USB) (Magenta/Violet)
    $btnExport = New-Object System.Windows.Forms.Button
    $btnExport.Text = "💾 Sauvegarder PC ➔ USB"
    $btnExport.Font = $emojiFontBtn
    $btnExport.Size = New-Object System.Drawing.Size(250, 35)
    $btnExport.Location = New-Object System.Drawing.Point(290, 25)
    $btnExport.BackColor = $btnColorExp
    $btnExport.ForeColor = $textColor
    $btnExport.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnExport.FlatAppearance.BorderSize = 0
    $btnExport.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnExport.Add_Click({ Export-SystemDrivers -ParentForm $ParentForm })
    $panelActions.Controls.Add($btnExport)

    # Bouton 3 : Installation (USB ➔ PC) (Violet Néon)
    $btnImport = New-Object System.Windows.Forms.Button
    $btnImport.Text = "📥 Installer USB ➔ PC"
    $btnImport.Font = $emojiFontBtn
    $btnImport.Size = New-Object System.Drawing.Size(250, 35)
    $btnImport.Location = New-Object System.Drawing.Point(565, 25)
    $btnImport.BackColor = $btnColorImp
    $btnImport.ForeColor = $textColor
    $btnImport.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnImport.FlatAppearance.BorderSize = 0
    $btnImport.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnImport.Add_Click({ Import-SystemDriversFromUSB -ParentForm $ParentForm })
    $panelActions.Controls.Add($btnImport)

    # Barre de chemin
    $driversPath = Get-R2ChapDriversPath

    $panelPath = New-Object System.Windows.Forms.Panel
    $panelPath.Location = New-Object System.Drawing.Point(10, 92)
    $panelPath.Size = New-Object System.Drawing.Size(840, 32)
    $panelPath.BackColor = $darkBg
    $panelPath.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $TargetTab.Controls.Add($panelPath)

    $txtPath = New-Object System.Windows.Forms.TextBox
    $txtPath.Text = "Dossier USB : $driversPath"
    $txtPath.Font = New-Object System.Drawing.Font("Segoe UI", 8.5, [System.Drawing.FontStyle]::Regular)
    $txtPath.ReadOnly = $true
    $txtPath.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $txtPath.BackColor = $darkBg
    $txtPath.ForeColor = $textColor
    $txtPath.Location = New-Object System.Drawing.Point(10, 7)
    $txtPath.Size = New-Object System.Drawing.Size(710, 18)
    $panelPath.Controls.Add($txtPath)

    $btnExplore = New-Object System.Windows.Forms.Button
    $btnExplore.Text = "📁 Explorer"
    $btnExplore.Font = $emojiFontBtn
    $btnExplore.Size = New-Object System.Drawing.Size(100, 24)
    $btnExplore.Location = New-Object System.Drawing.Point(732, 3)
    $btnExplore.BackColor = $btnColorDev
    $btnExplore.ForeColor = $textColor
    $btnExplore.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnExplore.FlatAppearance.BorderSize = 0
    $btnExplore.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnExplore.Add_Click({ Open-DriversDirectory })
    $panelPath.Controls.Add($btnExplore)

    # Cartes Outils
    $lblTools = New-Object System.Windows.Forms.Label
    $lblTools.Text = "Outils de diagnostic & utilitaires :"
    $lblTools.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $lblTools.ForeColor = $textColor
    $lblTools.Location = New-Object System.Drawing.Point(10, 132)
    $lblTools.Size = New-Object System.Drawing.Size(300, 20)
    $TargetTab.Controls.Add($lblTools)

    $appsPanel = New-Object System.Windows.Forms.Panel
    $appsPanel.Location = New-Object System.Drawing.Point(10, 155)
    $appsPanel.Size = New-Object System.Drawing.Size(840, 160)
    $appsPanel.AutoScroll = $true
    $TargetTab.Controls.Add($appsPanel)

    $toolsList = @(
        @{ Title = "HWiNFO64"; Category = "Info Matériel (USB)"; Icon = "💻"; Action = { Start-HWInfo } },
        @{ Title = "Firefox Portable"; Category = "Recherche Drivers (Sans Trace)"; Icon = "🦊"; Action = { Start-FirefoxPortable } },
        @{ Title = "Nettoyage Express"; Category = "Ferme Browsers & Vide Temp"; Icon = "🧹"; Action = { Clear-TempAndDownloads -ParentForm $ParentForm } }
    )

    $colCount = 3
    $cardWidth = 265
    $cardHeight = 65
    $spacing = 10

    for ($i = 0; $i -lt $toolsList.Count; $i++) {
        $item = $toolsList[$i]
        $row = [Math]::Floor($i / $colCount)
        $col = $i % $colCount

        $posX = $col * ($cardWidth + $spacing)
        $posY = $row * ($cardHeight + $spacing)

        $card = New-Object System.Windows.Forms.Panel
        $card.Size = New-Object System.Drawing.Size($cardWidth, $cardHeight)
        $card.Location = New-Object System.Drawing.Point($posX, $posY)
        $card.BackColor = $btnColorDev
        $card.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
        $card.Cursor = [System.Windows.Forms.Cursors]::Hand

        $lblIcon = New-Object System.Windows.Forms.Label
        $lblIcon.Text = $item.Icon
        $lblIcon.Font = $emojiFontCard
        $lblIcon.ForeColor = $textColor
        $lblIcon.Location = New-Object System.Drawing.Point(10, 12)
        $lblIcon.Size = New-Object System.Drawing.Size(40, 40)
        $lblIcon.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
        $card.Controls.Add($lblIcon)

        $lblName = New-Object System.Windows.Forms.Label
        $lblName.Text = $item.Title
        $lblName.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
        $lblName.ForeColor = $textColor
        $lblName.Location = New-Object System.Drawing.Point(58, 12)
        $lblName.Size = New-Object System.Drawing.Size(190, 20)

        $lblCat = New-Object System.Windows.Forms.Label
        $lblCat.Text = $item.Category
        $lblCat.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Italic)
        $lblCat.Location = New-Object System.Drawing.Point(58, 35)
        $lblCat.Size = New-Object System.Drawing.Size(190, 18)
        $lblCat.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#A0AAB0")

        $card.Controls.Add($lblName)
        $card.Controls.Add($lblCat)

        $clickEvent = $item.Action
        $card.Add_Click($clickEvent)
        $lblIcon.Add_Click($clickEvent)
        $lblName.Add_Click($clickEvent)
        $lblCat.Add_Click($clickEvent)

        $appsPanel.Controls.Add($card)
    }
}