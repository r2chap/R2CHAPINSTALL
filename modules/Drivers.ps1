# ==========================================
# MODULE : DRIVERS (Pilotes Nomades & Diagnostic)
# Fichier : modules/Drivers.ps1
# ==========================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic

# ------------------------------------------
# HELPER : LOGGING AVEC COULEURS
# ------------------------------------------
function Write-DriverLog {
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
        [System.Windows.Forms.Application]::DoEvents()
    }
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
    while ($CurrentDir -and $CurrentDir.Name -ne "R2CHAP" -and $CurrentDir.Parent) {
        $CurrentDir = $CurrentDir.Parent
    }

    if ($CurrentDir -and $CurrentDir.Name -eq "R2CHAP") { 
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
# FONCTIONS NATIVES : ACTIONS DU SYSTEME
# ------------------------------------------

function Open-DeviceManager {
    param([System.Windows.Forms.RichTextBox]$LogBox)
    Write-DriverLog -LogBox $LogBox -Message "ACTION : Ouverture du Gestionnaire de périphériques..." -Color ([System.Drawing.Color]::Cyan)
    try {
        Start-Process "devmgmt.msc"
    } catch {
        Write-DriverLog -LogBox $LogBox -Message "ERREUR : $($_.Exception.Message)" -Color ([System.Drawing.Color]::Red)
    }
}

# 1. SAUVEGARDE EN TEMPS RÉEL (PC ➔ USB)
function Export-SystemDrivers {
    param(
        [System.Windows.Forms.RichTextBox]$LogBox,
        [System.Windows.Forms.Form]$ParentForm
    )
    
    $defaultFolderName = "$($env:COMPUTERNAME)_$(Get-Date -Format 'yyyy-MM-dd')"
    
    $folderName = [Microsoft.VisualBasic.Interaction]::InputBox(
        "Entrez un nom pour le dossier de sauvegarde des pilotes :",
        "Sauvegarde des Pilotes PC ➔ USB",
        $defaultFolderName
    )

    if ([string]::IsNullOrWhiteSpace($folderName)) {
        Write-DriverLog -LogBox $LogBox -Message "Exportation annulée par l'utilisateur." -Color ([System.Drawing.Color]::Orange)
        return
    }

    $folderName = $folderName -replace '[\\/:*?"<>|]', '_'
    $TargetFolder = Get-R2ChapDriversPath -SubFolder $folderName

    Write-DriverLog -LogBox $LogBox -Message "==========================================" -Color ([System.Drawing.Color]::Cyan)
    Write-DriverLog -LogBox $LogBox -Message "ACTION : Sauvegarde des pilotes système..." -Color ([System.Drawing.Color]::Cyan)
    Write-DriverLog -LogBox $LogBox -Message "Dossier cible : $TargetFolder" -Color ([System.Drawing.Color]::Yellow)

    # Exécution via Job pour libérer le thread graphique
    $job = Start-Job -ScriptBlock {
        param($dest)
        Export-WindowsDriver -Online -Destination $dest -ErrorAction Stop
    } -ArgumentList $TargetFolder

    $seenFolders = @()

    # Suivi visuel continu dans le bloc RichTextBox
    while ($job.State -eq "Running") {
        [System.Windows.Forms.Application]::DoEvents()
        
        if (Test-Path $TargetFolder) {
            $currentFolders = Get-ChildItem -Path $TargetFolder -Directory -ErrorAction SilentlyContinue
            foreach ($dir in $currentFolders) {
                if ($seenFolders -notcontains $dir.Name) {
                    $seenFolders += $dir.Name
                    Write-DriverLog -LogBox $LogBox -Message " Extrait : $($dir.Name)" -Color ([System.Drawing.Color]::LightGreen)
                }
            }
        }
        Start-Sleep -Milliseconds 300
    }

    try {
        $result = Receive-Job -Job $job -ErrorAction Stop
        Remove-Job -Job $job -Force

        if (Test-Path $TargetFolder) {
            $currentFolders = Get-ChildItem -Path $TargetFolder -Directory -ErrorAction SilentlyContinue
            foreach ($dir in $currentFolders) {
                if ($seenFolders -notcontains $dir.Name) {
                    $seenFolders += $dir.Name
                    Write-DriverLog -LogBox $LogBox -Message " Extrait : $($dir.Name)" -Color ([System.Drawing.Color]::LightGreen)
                }
            }
        }

        Write-DriverLog -LogBox $LogBox -Message "--------------------------------------------------" -Color ([System.Drawing.Color]::Cyan)
        Write-DriverLog -LogBox $LogBox -Message "SUCCÈS : $($seenFolders.Count) dossier(s) de pilote(s) exporté(s) !" -Color ([System.Drawing.Color]::ForestGreen)
        Write-DriverLog -LogBox $LogBox -Message "Sauvegardé dans : $TargetFolder" -Color ([System.Drawing.Color]::ForestGreen)

    } catch {
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        Write-DriverLog -LogBox $LogBox -Message "ERREUR lors de l'exportation (Droits Admin requis) : $($_.Exception.Message)" -Color ([System.Drawing.Color]::Red)
    }
}

# 2. RESTAURATION CIBLÉE (USB ➔ PC)
function Import-SystemDriversFromUSB {
    param(
        [System.Windows.Forms.RichTextBox]$LogBox,
        [System.Windows.Forms.Form]$ParentForm
    )
    
    $baseDriversFolder = Get-R2ChapDriversPath

    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = "Sélectionnez le dossier contenant les pilotes à installer sur ce PC"
    $folderBrowser.SelectedPath = $baseDriversFolder
    $folderBrowser.ShowNewFolderButton = $false

    $dialogResult = $folderBrowser.ShowDialog()

    if ($dialogResult -ne [System.Windows.Forms.DialogResult]::OK -or [string]::IsNullOrWhiteSpace($folderBrowser.SelectedPath)) {
        Write-DriverLog -LogBox $LogBox -Message "Restauration annulée par l'utilisateur." -Color ([System.Drawing.Color]::Orange)
        return
    }

    $SelectedFolder = $folderBrowser.SelectedPath

    Write-DriverLog -LogBox $LogBox -Message "==========================================" -Color ([System.Drawing.Color]::Cyan)
    Write-DriverLog -LogBox $LogBox -Message "ACTION : Restauration des pilotes depuis USB..." -Color ([System.Drawing.Color]::Cyan)
    Write-DriverLog -LogBox $LogBox -Message "Dossier source : $SelectedFolder" -Color ([System.Drawing.Color]::Yellow)

    $infFiles = Get-ChildItem -Path $SelectedFolder -Recurse -Filter "*.inf" -ErrorAction SilentlyContinue

    if (-not $infFiles -or $infFiles.Count -eq 0) {
        Write-DriverLog -LogBox $LogBox -Message "ERREUR : Aucun fichier pilote (.inf) n'a été trouvé dans ce dossier." -Color ([System.Drawing.Color]::Red)
        return
    }

    Write-DriverLog -LogBox $LogBox -Message "Détection de $($infFiles.Count) fichier(s) .inf à installer..." -Color ([System.Drawing.Color]::White)

    try {
        $pnpArgs = "/add-driver `"$SelectedFolder\*.inf`" /subdirs /install"
        
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "pnputil.exe"
        $psi.Arguments = $pnpArgs
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $psi
        [void]$process.Start()

        while (-not $process.HasExited) {
            $line = $process.StandardOutput.ReadLine()
            if ($line) {
                if ($line -match "publié" -or $line -match "Published" -or $line -match "Ajouté") {
                    Write-DriverLog -LogBox $LogBox -Message " -> $line" -Color ([System.Drawing.Color]::LightGreen)
                } elseif ($line -match "Échec" -or $line -match "Failed") {
                    Write-DriverLog -LogBox $LogBox -Message " -> $line" -Color ([System.Drawing.Color]::Orange)
                }
            }
            [System.Windows.Forms.Application]::DoEvents()
        }

        $process.WaitForExit()

        Write-DriverLog -LogBox $LogBox -Message "--------------------------------------------------" -Color ([System.Drawing.Color]::Cyan)
        if ($process.ExitCode -eq 0) {
            Write-DriverLog -LogBox $LogBox -Message "SUCCÈS : Processus d'installation terminé !" -Color ([System.Drawing.Color]::ForestGreen)
        } else {
            Write-DriverLog -LogBox $LogBox -Message "FIN : Installation terminée avec le code $($process.ExitCode)." -Color ([System.Drawing.Color]::Yellow)
        }
    } catch {
        Write-DriverLog -LogBox $LogBox -Message "ERREUR lors de l'exécution de PNPUtil : $($_.Exception.Message)" -Color ([System.Drawing.Color]::Red)
    }
}

function Open-DriversDirectory {
    param([System.Windows.Forms.RichTextBox]$LogBox)
    $path = Get-R2ChapDriversPath
    Write-DriverLog -LogBox $LogBox -Message "ACTION : Ouverture de l'explorateur ($path)" -Color ([System.Drawing.Color]::Cyan)
    try {
        Start-Process "explorer.exe" -ArgumentList "`"$path`""
    } catch {
        Write-DriverLog -LogBox $LogBox -Message "ERREUR : $($_.Exception.Message)" -Color ([System.Drawing.Color]::Red)
    }
}

function Start-HWInfo {
    param([System.Windows.Forms.RichTextBox]$LogBox)
    $rootDir = Get-R2ChapBasePath
    $exePath = Join-Path $rootDir "apps\HWinfo\HWiNFO64.exe"

    Write-DriverLog -LogBox $LogBox -Message "ACTION : Lancement de HWiNFO64..." -Color ([System.Drawing.Color]::Cyan)
    
    if (Test-Path $exePath) {
        try { Start-Process $exePath } catch { Write-DriverLog -LogBox $LogBox -Message "ERREUR : $($_.Exception.Message)" -Color ([System.Drawing.Color]::Red) }
    } else {
        Write-DriverLog -LogBox $LogBox -Message "ERREUR : Fichier introuvable ($exePath)" -Color ([System.Drawing.Color]::Red)
    }
}

function Start-FirefoxPortable {
    param([System.Windows.Forms.RichTextBox]$LogBox)
    $rootDir = Get-R2ChapBasePath
    $exePath = Join-Path $rootDir "apps\FirefoxPortable\FirefoxPortable.exe"

    Write-DriverLog -LogBox $LogBox -Message "ACTION : Lancement de Firefox Portable..." -Color ([System.Drawing.Color]::Cyan)

    if (Test-Path $exePath) {
        try { Start-Process $exePath } catch { Write-DriverLog -LogBox $LogBox -Message "ERREUR : $($_.Exception.Message)" -Color ([System.Drawing.Color]::Red) }
    } else {
        Write-DriverLog -LogBox $LogBox -Message "ERREUR : Fichier introuvable ($exePath)" -Color ([System.Drawing.Color]::Red)
    }
}

# 3. NETTOYAGE EXPRESS FLUIDE ET EN TEMPS RÉEL
function Clear-TempAndDownloads {
    param(
        [System.Windows.Forms.RichTextBox]$LogBox,
        [System.Windows.Forms.Form]$ParentForm
    )

    $confirm = [System.Windows.Forms.MessageBox]::Show(
        "Le nettoyage express va fermer les navigateurs Web et supprimer le contenu des dossiers Temp et Téléchargements.`n`nSouhaitez-vous continuer ?",
        "Confirmation du nettoyage",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )

    if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) {
        Write-DriverLog -LogBox $LogBox -Message "Nettoyage annulé par l'utilisateur." -Color ([System.Drawing.Color]::Orange)
        return
    }

    Write-DriverLog -LogBox $LogBox -Message "==========================================" -Color ([System.Drawing.Color]::Cyan)
    Write-DriverLog -LogBox $LogBox -Message "ACTION : Démarrage du nettoyage express..." -Color ([System.Drawing.Color]::Cyan)

    # Fermeture dynamique des navigateurs
    $browsers = @("chrome", "msedge", "firefox", "brave", "opera")
    foreach ($proc in $browsers) {
        $runningProcs = Get-Process -Name $proc -ErrorAction SilentlyContinue
        if ($runningProcs) {
            Stop-Process -Name $proc -Force -ErrorAction SilentlyContinue
            Write-DriverLog -LogBox $LogBox -Message " Processus '$proc' fermé." -Color ([System.Drawing.Color]::OrangeRed)
            [System.Windows.Forms.Application]::DoEvents()
        }
    }

    Start-Sleep -Milliseconds 300

    # Ciblage dynamique selon l'utilisateur
    $userProfile = [Environment]::GetFolderPath("UserProfile")
    $userDownloads = Join-Path $userProfile "Downloads"
    $userTemp      = [System.IO.Path]::GetTempPath()
    $winTemp       = "C:\Windows\Temp"

    $foldersToClean = @(
        @{ Name = "Téléchargements ($env:USERNAME)"; Path = $userDownloads },
        @{ Name = "Temp Utilisateur"; Path = $userTemp },
        @{ Name = "Temp Windows"; Path = $winTemp }
    )

    $deletedCount = 0
    $skippedCount = 0

    foreach ($item in $foldersToClean) {
        $targetPath = $item.Path
        Write-DriverLog -LogBox $LogBox -Message "--- Nettoyage : $($item.Name) ---" -Color ([System.Drawing.Color]::Yellow)

        if (Test-Path $targetPath) {
            $elements = Get-ChildItem -Path $targetPath -ErrorAction SilentlyContinue

            if (-not $elements -or $elements.Count -eq 0) {
                Write-DriverLog -LogBox $LogBox -Message " Aucun fichier à supprimer ou dossier déjà vide." -Color ([System.Drawing.Color]::Gray)
                continue
            }

            foreach ($el in $elements) {
                # Rafraîchissement graphique immédiat
                [System.Windows.Forms.Application]::DoEvents()
                
                try {
                    Remove-Item -Path $el.FullName -Recurse -Force -ErrorAction Stop
                    $deletedCount++
                    Write-DriverLog -LogBox $LogBox -Message " Supprimé : $($el.Name)" -Color ([System.Drawing.Color]::LightGreen)
                } catch {
                    $skippedCount++
                    Write-DriverLog -LogBox $LogBox -Message " Ignoré (Verrouillé/Refusé) : $($el.Name)" -Color ([System.Drawing.Color]::Gray)
                }
            }
        } else {
            Write-DriverLog -LogBox $LogBox -Message " Dossier introuvable : $targetPath" -Color ([System.Drawing.Color]::Gray)
        }
    }

    Write-DriverLog -LogBox $LogBox -Message "--------------------------------------------------" -Color ([System.Drawing.Color]::Cyan)
    Write-DriverLog -LogBox $LogBox -Message "SUCCÈS : Nettoyage express terminé !" -Color ([System.Drawing.Color]::ForestGreen)
    Write-DriverLog -LogBox $LogBox -Message "Bilan : $deletedCount élément(s) supprimé(s), $skippedCount verrouillé(s) ignoré(s)." -Color ([System.Drawing.Color]::White)
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

    $emojiFontBtn = New-Object System.Drawing.Font("Segoe UI Emoji", 8.5, [System.Drawing.FontStyle]::Bold)
    $emojiFontCard = New-Object System.Drawing.Font("Segoe UI Emoji", 15)

    # Console Log
    $logBox = New-Object System.Windows.Forms.RichTextBox
    $logBox.Location = New-Object System.Drawing.Point(10, 310)
    $logBox.Size = New-Object System.Drawing.Size(840, 145)
    $logBox.BackColor = [System.Drawing.Color]::Black
    $logBox.ForeColor = [System.Drawing.Color]::White
    $logBox.ReadOnly = $true
    $logBox.Font = New-Object System.Drawing.Font("Consolas", 9.5, [System.Drawing.FontStyle]::Regular)
    $TargetTab.Controls.Add($logBox)

    Write-DriverLog -LogBox $logBox -Message "Module Pilotes initialisé. Prêt à l'emploi." -Color ([System.Drawing.Color]::LightGray)

    # Actions du haut
    $panelActions = New-Object System.Windows.Forms.GroupBox
    $panelActions.Text = " Actions USB & Système "
    $panelActions.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
    $panelActions.Location = New-Object System.Drawing.Point(10, 10)
    $panelActions.Size = New-Object System.Drawing.Size(840, 75)
    $TargetTab.Controls.Add($panelActions)

    # Bouton 1 : Gestionnaire de périphériques
    $btnScan = New-Object System.Windows.Forms.Button
    $btnScan.Text = "🔍 Gestionnaire périphérique"
    $btnScan.Font = $emojiFontBtn
    $btnScan.Size = New-Object System.Drawing.Size(250, 35)
    $btnScan.Location = New-Object System.Drawing.Point(15, 25)
    $btnScan.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#17A2B8")
    $btnScan.ForeColor = [System.Drawing.Color]::White
    $btnScan.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnScan.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnScan.Add_Click({ Open-DeviceManager -LogBox $logBox })
    $panelActions.Controls.Add($btnScan)

    # Bouton 2 : Sauvegarde (PC ➔ USB)
    $btnExport = New-Object System.Windows.Forms.Button
    $btnExport.Text = "💾 Sauvegarder PC ➔ USB"
    $btnExport.Font = $emojiFontBtn
    $btnExport.Size = New-Object System.Drawing.Size(250, 35)
    $btnExport.Location = New-Object System.Drawing.Point(290, 25)
    $btnExport.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#28A745")
    $btnExport.ForeColor = [System.Drawing.Color]::White
    $btnExport.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnExport.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnExport.Add_Click({ Export-SystemDrivers -LogBox $logBox -ParentForm $ParentForm })
    $panelActions.Controls.Add($btnExport)

    # Bouton 3 : Installation (USB ➔ PC)
    $btnImport = New-Object System.Windows.Forms.Button
    $btnImport.Text = "📥 Installer USB ➔ PC"
    $btnImport.Font = $emojiFontBtn
    $btnImport.Size = New-Object System.Drawing.Size(250, 35)
    $btnImport.Location = New-Object System.Drawing.Point(565, 25)
    $btnImport.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#007ACC")
    $btnImport.ForeColor = [System.Drawing.Color]::White
    $btnImport.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnImport.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnImport.Add_Click({ Import-SystemDriversFromUSB -LogBox $logBox -ParentForm $ParentForm })
    $panelActions.Controls.Add($btnImport)

    # Barre de chemin
    $driversPath = Get-R2ChapDriversPath

    $panelPath = New-Object System.Windows.Forms.Panel
    $panelPath.Location = New-Object System.Drawing.Point(10, 92)
    $panelPath.Size = New-Object System.Drawing.Size(840, 32)
    $panelPath.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#D8E9FE")
    $panelPath.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $TargetTab.Controls.Add($panelPath)

    $txtPath = New-Object System.Windows.Forms.TextBox
    $txtPath.Text = "Dossier USB : $driversPath"
    $txtPath.Font = New-Object System.Drawing.Font("Segoe UI", 8.5, [System.Drawing.FontStyle]::Regular)
    $txtPath.ReadOnly = $true
    $txtPath.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $txtPath.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#D8E9FE")
    $txtPath.Location = New-Object System.Drawing.Point(10, 7)
    $txtPath.Size = New-Object System.Drawing.Size(710, 18)
    $panelPath.Controls.Add($txtPath)

    $btnExplore = New-Object System.Windows.Forms.Button
    $btnExplore.Text = "📁 Explorer"
    $btnExplore.Font = $emojiFontBtn
    $btnExplore.Size = New-Object System.Drawing.Size(100, 24)
    $btnExplore.Location = New-Object System.Drawing.Point(732, 3)
    $btnExplore.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#6C757D")
    $btnExplore.ForeColor = [System.Drawing.Color]::White
    $btnExplore.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnExplore.FlatAppearance.BorderSize = 0
    $btnExplore.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnExplore.Add_Click({ Open-DriversDirectory -LogBox $logBox })
    $panelPath.Controls.Add($btnExplore)

    # Cartes Outils
    $lblTools = New-Object System.Windows.Forms.Label
    $lblTools.Text = "Outils de diagnostic & utilitaires :"
    $lblTools.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $lblTools.Location = New-Object System.Drawing.Point(10, 132)
    $lblTools.Size = New-Object System.Drawing.Size(300, 20)
    $TargetTab.Controls.Add($lblTools)

    $appsPanel = New-Object System.Windows.Forms.Panel
    $appsPanel.Location = New-Object System.Drawing.Point(10, 155)
    $appsPanel.Size = New-Object System.Drawing.Size(840, 145)
    $appsPanel.AutoScroll = $true
    $TargetTab.Controls.Add($appsPanel)

    $toolsList = @(
        @{ Title = "HWiNFO64"; Category = "Info Matériel (USB)"; Icon = "💻"; Action = { Start-HWInfo -LogBox $logBox } },
        @{ Title = "Firefox Portable"; Category = "Recherche Drivers (Sans Trace)"; Icon = "🦊"; Action = { Start-FirefoxPortable -LogBox $logBox } },
        @{ Title = "Nettoyage Express"; Category = "Ferme Browsers & Vide Temp"; Icon = "🧹"; Action = { Clear-TempAndDownloads -LogBox $logBox -ParentForm $ParentForm } }
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
        $card.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#BAE6FF")
        $card.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
        $card.Cursor = [System.Windows.Forms.Cursors]::Hand

        $lblIcon = New-Object System.Windows.Forms.Label
        $lblIcon.Text = $item.Icon
        $lblIcon.Font = $emojiFontCard
        $lblIcon.Location = New-Object System.Drawing.Point(10, 12)
        $lblIcon.Size = New-Object System.Drawing.Size(40, 40)
        $lblIcon.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
        $card.Controls.Add($lblIcon)

        $lblName = New-Object System.Windows.Forms.Label
        $lblName.Text = $item.Title
        $lblName.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
        $lblName.Location = New-Object System.Drawing.Point(58, 12)
        $lblName.Size = New-Object System.Drawing.Size(190, 20)

        $lblCat = New-Object System.Windows.Forms.Label
        $lblCat.Text = $item.Category
        $lblCat.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Italic)
        $lblCat.Location = New-Object System.Drawing.Point(58, 35)
        $lblCat.Size = New-Object System.Drawing.Size(190, 18)
        $lblCat.ForeColor = [System.Drawing.Color]::DimGray

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