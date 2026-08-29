# ==========================================
# MODULE : SOFTWARE (Programme)
# Fichier : modules/Software.ps1
# ==========================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ------------------------------------------
# LISTE DES LOGICIELS (IDs Winget valides)
# ------------------------------------------
$script:AppList = @(
    @{ Name = "Chrome";        Id = "Google.Chrome";           Category = "Navigateur";  IconFile = "chrome.png";   FallbackIcon = "🌐" },
    @{ Name = "Firefox";       Id = "Mozilla.Firefox";          Category = "Navigateur";  IconFile = "firefox.png";  FallbackIcon = "🦊" },
    @{ Name = "Opera";         Id = "Opera.OperaBrowser";      Category = "Navigateur";  IconFile = "opera.png";    FallbackIcon = "🔴" },
    @{ Name = "Foxit Reader";  Id = "Foxit.FoxitReader";        Category = "Bureautique"; IconFile = "foxit.png";    FallbackIcon = "📄" },
    @{ Name = "VLC";           Id = "VideoLAN.VLC";             Category = "Média";       IconFile = "vlc.png";      FallbackIcon = "📙" },
    @{ Name = "Notepad++";     Id = "Notepad++.Notepad++";      Category = "Utilitaires"; IconFile = "notepad.png";  FallbackIcon = "📝" },
    @{ Name = "GIMP";          Id = "GIMP.GIMP";                Category = "Graphisme";   IconFile = "gimp.png";     FallbackIcon = "🎨" },
    @{ Name = "7-Zip";         Id = "7zip.7zip";                Category = "Archivage";   IconFile = "7zip.png";     FallbackIcon = "📦" },
    # Double installation : Viewer + Middleware
    @{ Name = "EidBelgium";    Id = @("BelgianGovernment.eIDViewer", "BelgianGovernment.eIDmiddleware"); Category = "Sécurité"; IconFile = "eid.png"; FallbackIcon = "💳" }
)

# ------------------------------------------
# HELPER : CHARGEMENT / REDIMENSIONNEMENT IMAGE
# ------------------------------------------
function Get-AppIconImage {
    param(
        [string]$FileName,
        [int]$Width = 40,
        [int]$Height = 40
    )

    $ScriptDir = $PSScriptRoot
    if (-not $ScriptDir) {
        if ($MyInvocation.MyCommand.Path) {
            $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
        } else {
            $ScriptDir = Get-Location
        }
    }

    $RootDir = Split-Path -Parent $ScriptDir
    $AssetsDir = Join-Path $RootDir "assets"
    $FilePath = Join-Path $AssetsDir $FileName

    if (-not [string]::IsNullOrWhiteSpace($FileName) -and (Test-Path -Path $FilePath -PathType Leaf)) {
        try {
            $origImg = [System.Drawing.Image]::FromFile($FilePath)
            $bmp = New-Object System.Drawing.Bitmap($Width, $Height)
            $graph = [System.Drawing.Graphics]::FromImage($bmp)
            $graph.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graph.DrawImage($origImg, 0, 0, $Width, $Height)
            $origImg.Dispose()
            $graph.Dispose()
            return $bmp
        } catch {
            return $null
        }
    }
    return $null
}

# ------------------------------------------
# HELPER : LOGGING
# ------------------------------------------
function Write-SoftwareLog {
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
# HELPER : TRADUCTION DES CODES D'ERREUR WINGET
# ------------------------------------------
function Get-WingetErrorMessage {
    param([int]$Code)

    switch ($Code) {
        0           { return "Installation réussie." }
        -1978335189 { return "Le logiciel est déjà installé dans sa dernière version." }
        -1978335212 { return "Impossible de télécharger l'installateur (Lien mort ou problème réseau)." }
        -1978335188 { return "Installation annulée par l'utilisateur." }
        -1978335211 { return "Fichier d'installation corrompu ou signature invalide." }
        -1978335184 { return "Redémarrage du système requis pour finaliser l'installation." }
        1602        { return "L'installation a été annulée." }
        1603        { return "Erreur fatale lors de l'installation (droits Administrateur manquants ?)." }
        1618        { return "Une autre installation est déjà en cours. Patientez puis réessayez." }
        default     { return "Échec de l'installation (Code : $Code)." }
    }
}

# ------------------------------------------
# BLOC DE CODE D'INSTALLATION
# ------------------------------------------
$script:InvokeInstallBlock = {
    param(
        [array]$AppsToInstall,
        [System.Windows.Forms.Button]$BtnInstallAll,
        [System.Windows.Forms.ProgressBar]$ProgressBar,
        [System.Windows.Forms.RichTextBox]$LogBox,
        [System.Windows.Forms.Form]$ParentForm
    )
    
    # Calcul du nombre total d'éléments (en décomposant si un item contient plusieurs IDs)
    $totalPackages = 0
    foreach ($app in $AppsToInstall) {
        if ($app.Id -is [array]) {
            $totalPackages += $app.Id.Count
        } else {
            $totalPackages += 1
        }
    }

    if ($BtnInstallAll)  { $BtnInstallAll.Enabled = $false }
    if ($ProgressBar)    { $ProgressBar.Value = 0; $ProgressBar.Maximum = $totalPackages + 1 }

    # ÉTAPE 1 : MISE À JOUR DES SOURCES WINGET
    Write-SoftwareLog -LogBox $LogBox -Message "Mise à jour des catalogues de sources Winget..." -Color ([System.Drawing.Color]::Blue)
    if ($ParentForm) { $ParentForm.Refresh() }

    $updateProcess = Start-Process -FilePath "winget" -ArgumentList "source update" -NoNewWindow -PassThru -Wait
    if ($ProgressBar) { $ProgressBar.Value = 1 }

    Write-SoftwareLog -LogBox $LogBox -Message "Début de l'installation ($totalPackages paquet(s) au total)..." -Color ([System.Drawing.Color]::Blue)

    # ÉTAPE 2 : INSTALLATION DES APPLICATIONS
    $step = 1
    foreach ($app in $AppsToInstall) {
        
        # Conversion systématique en tableau pour supporter 1 ou plusieurs IDs par carte
        $pkgList = @($app.Id)

        foreach ($pkgId in $pkgList) {
            $step++
            Write-SoftwareLog -LogBox $LogBox -Message "Installation de $($app.Name) [$pkgId]..." -Color ([System.Drawing.Color]::DarkSlateGray)
            if ($ParentForm) { $ParentForm.Refresh() }

            $process = Start-Process -FilePath "winget" -ArgumentList "install --id `"$pkgId`" -s winget -e --silent --accept-package-agreements --accept-source-agreements" -NoNewWindow -PassThru -Wait
            
            $exitCode = $process.ExitCode
            $statusMessage = Get-WingetErrorMessage -Code $exitCode

            if ($exitCode -eq 0 -or $exitCode -eq -1978335189) {
                Write-SoftwareLog -LogBox $LogBox -Message "SUCCÈS : $pkgId -> $statusMessage" -Color ([System.Drawing.Color]::ForestGreen)
            } else {
                Write-SoftwareLog -LogBox $LogBox -Message "ERREUR : $pkgId -> $statusMessage" -Color ([System.Drawing.Color]::Red)
            }

            if ($ProgressBar) { $ProgressBar.Value = [Math]::Min($step, $ProgressBar.Maximum) }
            if ($ParentForm)  { $ParentForm.Refresh() }
        }
    }

    Write-SoftwareLog -LogBox $LogBox -Message "Opérations terminées." -Color ([System.Drawing.Color]::Blue)
    if ($BtnInstallAll) { $BtnInstallAll.Enabled = $true }
}

# ------------------------------------------
# CONSTRUCTION DE L'ONGLET PROGRAMME
# ------------------------------------------
function Build-TabProgramme {
    param(
        [System.Windows.Forms.TabPage]$TargetTab,
        [System.Windows.Forms.Form]$ParentForm,
        [System.Drawing.Color]$BgColor
    )

    # Bouton Tout Installer
    $btnInstallAll = New-Object System.Windows.Forms.Button
    $btnInstallAll.Text = "⚡ Installer tous les programmes"
    $btnInstallAll.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
    $btnInstallAll.Size = New-Object System.Drawing.Size(250, 32)
    $btnInstallAll.Location = New-Object System.Drawing.Point(10, 10)
    $btnInstallAll.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#28A745")
    $btnInstallAll.ForeColor = [System.Drawing.Color]::White
    $btnInstallAll.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnInstallAll.FlatAppearance.BorderSize = 0
    $btnInstallAll.Cursor = [System.Windows.Forms.Cursors]::Hand
    $TargetTab.Controls.Add($btnInstallAll)

    # Conteneur des cartes d'applications
    $appsPanel = New-Object System.Windows.Forms.Panel
    $appsPanel.Location = New-Object System.Drawing.Point(10, 50)
    $appsPanel.Size = New-Object System.Drawing.Size(840, 240)
    $appsPanel.AutoScroll = $true
    $TargetTab.Controls.Add($appsPanel)

    # Console de Log
    $logBox = New-Object System.Windows.Forms.RichTextBox
    $logBox.Location = New-Object System.Drawing.Point(10, 310)
    $logBox.Size = New-Object System.Drawing.Size(840, 115)
    $logBox.BackColor = [System.Drawing.Color]::White
    $logBox.ReadOnly = $true
    $logBox.Font = New-Object System.Drawing.Font("Consolas", 9.5, [System.Drawing.FontStyle]::Regular)
    $TargetTab.Controls.Add($logBox)

    # Barre de progression
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(10, 435)
    $progressBar.Size = New-Object System.Drawing.Size(840, 20)
    $progressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Continuous
    $TargetTab.Controls.Add($progressBar)

    # Grille 3 colonnes
    $colCount = 3
    $cardWidth = 265
    $cardHeight = 65
    $spacing = 10

    for ($i = 0; $i -lt $script:AppList.Count; $i++) {
        $app = $script:AppList[$i]
        $row = [Math]::Floor($i / $colCount)
        $col = $i % $colCount

        $posX = $col * ($cardWidth + $spacing)
        $posY = $row * ($cardHeight + $spacing)

        $card = New-Object System.Windows.Forms.Panel
        $card.Size = New-Object System.Drawing.Size($cardWidth, $cardHeight)
        $card.Location = New-Object System.Drawing.Point($posX, $posY)
        $card.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#A2CDFF")
        $card.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
        $card.Cursor = [System.Windows.Forms.Cursors]::Hand

        # Chargement de l'icône PNG ou repli sur l'émoji
        $imgIcon = Get-AppIconImage -FileName $app.IconFile -Width 40 -Height 40

        if ($imgIcon) {
            $picIcon = New-Object System.Windows.Forms.PictureBox
            $picIcon.Image = $imgIcon
            $picIcon.Location = New-Object System.Drawing.Point(10, 12)
            $picIcon.Size = New-Object System.Drawing.Size(40, 40)
            $picIcon.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
            $card.Controls.Add($picIcon)
            $iconControl = $picIcon
        } else {
            $lblIcon = New-Object System.Windows.Forms.Label
            $lblIcon.Text = $app.FallbackIcon
            $lblIcon.Font = New-Object System.Drawing.Font("Segoe UI", 16)
            $lblIcon.Location = New-Object System.Drawing.Point(10, 15)
            $lblIcon.Size = New-Object System.Drawing.Size(35, 35)
            $lblIcon.ForeColor = [System.Drawing.Color]::Black
            $card.Controls.Add($lblIcon)
            $iconControl = $lblIcon
        }

        $lblName = New-Object System.Windows.Forms.Label
        $lblName.Text = $app.Name
        $lblName.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
        $lblName.Location = New-Object System.Drawing.Point(58, 12)
        $lblName.Size = New-Object System.Drawing.Size(190, 20)
        $lblName.ForeColor = [System.Drawing.Color]::Black

        $lblCat = New-Object System.Windows.Forms.Label
        $lblCat.Text = $app.Category
        $lblCat.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Italic)
        $lblCat.Location = New-Object System.Drawing.Point(58, 35)
        $lblCat.Size = New-Object System.Drawing.Size(190, 18)
        $lblCat.ForeColor = [System.Drawing.Color]::DimGray

        $card.Controls.Add($lblName)
        $card.Controls.Add($lblCat)

        # Action Clic
        $appTarget = $app
        $bInstall = $btnInstallAll
        $pBar = $progressBar
        $lBox = $logBox
        $pForm = $ParentForm
        $installBlock = $script:InvokeInstallBlock

        $actionClick = {
            & $installBlock -AppsToInstall @($appTarget) -BtnInstallAll $bInstall -ProgressBar $pBar -LogBox $lBox -ParentForm $pForm
        }.GetNewClosure()

        $card.Add_Click($actionClick)
        $iconControl.Add_Click($actionClick)
        $lblName.Add_Click($actionClick)
        $lblCat.Add_Click($actionClick)

        $appsPanel.Controls.Add($card)
    }

    # Clic Tout Installer
    $bInstall = $btnInstallAll
    $pBar = $progressBar
    $lBox = $logBox
    $pForm = $ParentForm
    $installBlock = $script:InvokeInstallBlock

    $btnInstallAll.Add_Click({
        & $installBlock -AppsToInstall $script:AppList -BtnInstallAll $bInstall -ProgressBar $pBar -LogBox $lBox -ParentForm $pForm
    }.GetNewClosure())
}