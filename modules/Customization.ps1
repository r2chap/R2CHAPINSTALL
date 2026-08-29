# ==========================================
# MODULE : CUSTOMIZATION (Personnalisation & Multimédia)
# Fichier : modules/Customization.ps1
# ==========================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# API Native Windows pour appliquer le fond d'écran sans redémarrer
$WallpaperAPI = @"
using System;
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@
if (-not ([System.Management.Automation.PSTypeName]'Wallpaper').Type) {
    Add-Type -TypeDefinition $WallpaperAPI
}

# ------------------------------------------
# HELPER : LOGGING
# ------------------------------------------
function Write-CustomLog {
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
# HELPERS : DÉTECTION DES CHEMINS (USB & C:\r2chap)
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

function Get-LocalAssetFile {
    param(
        [string]$FileName,
        [System.Windows.Forms.RichTextBox]$LogBox
    )
    
    $localFolder = "C:\r2chap"
    if (-not (Test-Path $localFolder)) {
        New-Item -ItemType Directory -Path $localFolder -Force | Out-Null
    }

    $localPath = Join-Path $localFolder $FileName

    if (Test-Path $localPath) {
        return $localPath
    }

    $rootDir = Get-R2ChapBasePath
    $assetPath = Join-Path $rootDir "assets\$FileName"

    if (Test-Path $assetPath) {
        try {
            Copy-Item -Path $assetPath -Destination $localPath -Force
            Write-CustomLog -LogBox $LogBox -Message " Asset copié depuis USB vers : $localPath" -Color ([System.Drawing.Color]::Gray)
            return $localPath
        } catch {
            Write-CustomLog -LogBox $LogBox -Message " ERREUR de copie de $FileName depuis USB : $($_.Exception.Message)" -Color ([System.Drawing.Color]::Red)
            return $null
        }
    } else {
        Write-CustomLog -LogBox $LogBox -Message " ERREUR : Fichier '$FileName' introuvable dans C:\r2chap et Assets USB ($assetPath)." -Color ([System.Drawing.Color]::Red)
        return $null
    }
}

# ------------------------------------------
# BLOC DE CODE D'INSTALLATION DE LOGICIELS (ÉQUIVALENT AU MODULE SOFTWARE)
# ------------------------------------------
$script:InvokeWingetInstallBlock = {
    param(
        [string]$AppName,
        [string]$AppId,
        [System.Windows.Forms.RichTextBox]$LogBox,
        [System.Windows.Forms.ProgressBar]$ProgressBar,
        [System.Windows.Forms.Form]$ParentForm
    )

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-CustomLog -LogBox $LogBox -Message "ERREUR : L'outil 'winget' n'est pas disponible sur ce système." -Color ([System.Drawing.Color]::Red)
        return
    }

    if ($ProgressBar) { 
        $ProgressBar.Value = 0
        $ProgressBar.Maximum = 2
    }

    # Recherche si l'ID n'est pas fourni (ex: Romstation)
    $targetId = $AppId
    if ([string]::IsNullOrWhiteSpace($targetId)) {
        Write-CustomLog -LogBox $LogBox -Message "Recherche du paquet '$AppName' dans WinGet..." -Color ([System.Drawing.Color]::Blue)
        if ($ParentForm) { $ParentForm.Refresh() }

        $searchProc = Start-Process -FilePath "winget" -ArgumentList "search `"$AppName`" --accept-source-agreements" -NoNewWindow -PassThru -Wait
        
        # Si la recherche ne retourne rien de probant, on tente avec le nom brut
        $targetId = $AppName
    }

    if ($ProgressBar) { $ProgressBar.Value = 1 }

    Write-CustomLog -LogBox $LogBox -Message "Installation de $AppName [$targetId]..." -Color ([System.Drawing.Color]::DarkSlateGray)
    if ($ParentForm) { $ParentForm.Refresh() }

    # Exécution silencieuse standard conforme à Software.ps1
    $process = Start-Process -FilePath "winget" -ArgumentList "install --id `"$targetId`" -s winget -e --silent --accept-package-agreements --accept-source-agreements" -NoNewWindow -PassThru -Wait

    $exitCode = $process.ExitCode
    $statusMessage = Get-WingetErrorMessage -Code $exitCode

    if ($exitCode -eq 0 -or $exitCode -eq -1978335189) {
        Write-CustomLog -LogBox $LogBox -Message "SUCCÈS : $AppName -> $statusMessage" -Color ([System.Drawing.Color]::ForestGreen)
    } else {
        Write-CustomLog -LogBox $LogBox -Message "ERREUR : $AppName -> $statusMessage" -Color ([System.Drawing.Color]::Red)
    }

    if ($ProgressBar) { 
        $ProgressBar.Value = 2 
    }
    if ($ParentForm) { $ParentForm.Refresh() }
}

# ------------------------------------------
# ACTIONS DE PERSONNALISATION & RÉSEAU
# ------------------------------------------

# 1. RACCOURCI WEB SUR LE BUREAU
function Set-DesktopShortcut {
    param([System.Windows.Forms.RichTextBox]$LogBox)

    Write-CustomLog -LogBox $LogBox -Message "==========================================" -Color ([System.Drawing.Color]::Blue)
    Write-CustomLog -LogBox $LogBox -Message "ACTION : Création du raccourci Web sur le bureau..." -Color ([System.Drawing.Color]::Blue)

    $iconPath = Get-LocalAssetFile -FileName "Logo.ico" -LogBox $LogBox
    $desktopPath = [Environment]::GetFolderPath("Desktop")
    $shortcutPath = Join-Path $desktopPath "R2CHAP.url"

    try {
        $content = @"
[{000214A0-0000-0000-C000-000000000046}]
Prop3=19,2
[InternetShortcut]
IDList=
URL=https://r2chap.be
"@
        if ($iconPath -and (Test-Path $iconPath)) {
            $content += "`nIconFile=$iconPath`nIconIndex=0"
        }

        Set-Content -Path $shortcutPath -Value $content -Encoding ASCII -Force
        Write-CustomLog -LogBox $LogBox -Message "SUCCÈS : Raccourci vers https://r2chap.be créé sur le bureau." -Color ([System.Drawing.Color]::ForestGreen)
    } catch {
        Write-CustomLog -LogBox $LogBox -Message "ERREUR lors de la création du raccourci : $($_.Exception.Message)" -Color ([System.Drawing.Color]::Red)
    }
}

# 2. APPLICATION DU FOND D'ÉCRAN
function Set-DesktopWallpaper {
    param([System.Windows.Forms.RichTextBox]$LogBox)

    Write-CustomLog -LogBox $LogBox -Message "==========================================" -Color ([System.Drawing.Color]::Blue)
    Write-CustomLog -LogBox $LogBox -Message "ACTION : Modification du fond d'écran..." -Color ([System.Drawing.Color]::Blue)

    $wallpaperPath = Get-LocalAssetFile -FileName "wallpaper.png" -LogBox $LogBox

    if (-not $wallpaperPath -or -not (Test-Path $wallpaperPath)) {
        Write-CustomLog -LogBox $LogBox -Message "ÉCHEC : Impossible d'appliquer le fond d'écran (fichier introuvable)." -Color ([System.Drawing.Color]::Red)
        return
    }

    try {
        Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name wallpaper -Value $wallpaperPath
        Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name WallpaperStyle -Value "2"
        Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name TileWallpaper -Value "0"

        [Wallpaper]::SystemParametersInfo(0x0014, 0, $wallpaperPath, 0x01 -bor 0x02) | Out-Null
        
        Write-CustomLog -LogBox $LogBox -Message "SUCCÈS : Fond d'écran appliqué avec succès." -Color ([System.Drawing.Color]::ForestGreen)
    } catch {
        Write-CustomLog -LogBox $LogBox -Message "ERREUR lors du changement de fond d'écran : $($_.Exception.Message)" -Color ([System.Drawing.Color]::Red)
    }
}

# 3. MODIFICATION DE L'AVATAR UTILISATEUR
function Set-UserAvatar {
    param([System.Windows.Forms.RichTextBox]$LogBox)

    Write-CustomLog -LogBox $LogBox -Message "==========================================" -Color ([System.Drawing.Color]::Blue)
    Write-CustomLog -LogBox $LogBox -Message "ACTION : Modification de la photo de profil utilisateur..." -Color ([System.Drawing.Color]::Blue)

    $avatarPath = Get-LocalAssetFile -FileName "user_avatar.png" -LogBox $LogBox

    if (-not $avatarPath -or -not (Test-Path $avatarPath)) {
        Write-CustomLog -LogBox $LogBox -Message "ÉCHEC : Impossible de modifier l'avatar (fichier introuvable)." -Color ([System.Drawing.Color]::Red)
        return
    }

    try {
        $accountPicturesDir = Join-Path $env:PUBLIC "AccountPictures"
        if (-not (Test-Path $accountPicturesDir)) {
            New-Item -ItemType Directory -Path $accountPicturesDir -Force | Out-Null
        }

        $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AccountPicture\Users\$((Get-LocalUser $env:USERNAME).SID)"
        if (-not (Test-Path $regPath)) {
            New-Item -Path $regPath -Force | Out-Null
        }
        Set-ItemProperty -Path $regPath -Name "Image32" -Value $avatarPath -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $regPath -Name "Image96" -Value $avatarPath -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $regPath -Name "Image240" -Value $avatarPath -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $regPath -Name "Image448" -Value $avatarPath -ErrorAction SilentlyContinue

        Write-CustomLog -LogBox $LogBox -Message "SUCCÈS : Photo de profil définie sur $avatarPath." -Color ([System.Drawing.Color]::ForestGreen)
    } catch {
        Write-CustomLog -LogBox $LogBox -Message "ERREUR lors du changement d'avatar : $($_.Exception.Message)" -Color ([System.Drawing.Color]::Red)
    }
}

# 4. CONFIGURATION DU THÈME ET COULEURS WINDOWS
function Set-WindowsThemeAndColors {
    param([System.Windows.Forms.RichTextBox]$LogBox)

    Write-CustomLog -LogBox $LogBox -Message "==========================================" -Color ([System.Drawing.Color]::Blue)
    Write-CustomLog -LogBox $LogBox -Message "ACTION : Application du thème et des couleurs d'accentuation..." -Color ([System.Drawing.Color]::Blue)

    try {
        $personalizePath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"
        $dwmPath         = "HKCU:\SOFTWARE\Microsoft\Windows\DWM"

        if (-not (Test-Path $personalizePath)) { New-Item -Path $personalizePath -Force | Out-Null }
        if (-not (Test-Path $dwmPath)) { New-Item -Path $dwmPath -Force | Out-Null }

        Set-ItemProperty -Path $personalizePath -Name "SystemUsesLightTheme" -Value 0 -Force
        Set-ItemProperty -Path $personalizePath -Name "AppsUseLightTheme" -Value 1 -Force

        Set-ItemProperty -Path $personalizePath -Name "AutoColorization" -Value 1 -Force
        Set-ItemProperty -Path $dwmPath -Name "ColorPrevalence" -Value 1 -Force

        Set-ItemProperty -Path $personalizePath -Name "ColorPrevalence" -Value 1 -Force
        Set-ItemProperty -Path $dwmPath -Name "AccentColorMenu" -Value 1 -ErrorAction SilentlyContinue

        Write-CustomLog -LogBox $LogBox -Message "SUCCÈS : Thème Sombre/Clair & Couleurs d'accentuation configurés." -Color ([System.Drawing.Color]::ForestGreen)
    } catch {
        Write-CustomLog -LogBox $LogBox -Message "ERREUR lors de la configuration du thème : $($_.Exception.Message)" -Color ([System.Drawing.Color]::Red)
    }
}

# 5. CONFIGURATION DU DNS VERS OPENDNS (APPLICATION SUR TOUTES LES CARTES PHYSIQUES)
function Set-OpenDNSConfig {
    param([System.Windows.Forms.RichTextBox]$LogBox)

    Write-CustomLog -LogBox $LogBox -Message "==========================================" -Color ([System.Drawing.Color]::Blue)
    Write-CustomLog -LogBox $LogBox -Message "ACTION : Configuration d'OpenDNS sur toutes les cartes réseau physiques..." -Color ([System.Drawing.Color]::Blue)

    try {
        # Détection de TOUTES les cartes physiques (Ethernet et Wi-Fi) en excluant les cartes virtuelles
        $adapters = Get-NetAdapter -ErrorAction Stop | Where-Object { 
            $_.HardwareInterface -eq $true -and 
            $_.Name -notmatch "Virtual|VMware|vEthernet|Loopback|WSL|Bluetooth" -and
            $_.InterfaceDescription -notmatch "Virtual|VMware|Hyper-V|TAP|TUN"
        }

        if (-not $adapters -or $adapters.Count -eq 0) {
            Write-CustomLog -LogBox $LogBox -Message "ERREUR : Aucune carte réseau physique (Ethernet/Wi-Fi) n'a été trouvée." -Color ([System.Drawing.Color]::Red)
            [System.Windows.Forms.MessageBox]::Show("Aucune carte réseau physique n'a été détectée.", "Erreur Réseau", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            return
        }

        $modifiedAdapters = @()

        foreach ($adapter in $adapters) {
            $adapterName = $adapter.Name
            Write-CustomLog -LogBox $LogBox -Message " Traitement de l'interface : $adapterName ($($adapter.InterfaceDescription))" -Color ([System.Drawing.Color]::DarkSlateGray)

            # 1. Reset et attribution via cmdlet PowerShell
            Set-DnsClientServerAddress -InterfaceAlias $adapterName -ResetServerAddresses -ErrorAction SilentlyContinue
            Set-DnsClientServerAddress -InterfaceAlias $adapterName -ServerAddresses ("208.67.222.222", "208.67.220.220") -ErrorAction SilentlyContinue

            # 2. Force l'attribution statique via Netsh (Met à jour l'interface Windows 11)
            $cmdPrimary = "interface ipv4 set dns name=`"$adapterName`" static 208.67.222.222 primary"
            $cmdSecondary = "interface ipv4 add dns name=`"$adapterName`" 208.67.220.220 index=2"

            Start-Process netsh -ArgumentList $cmdPrimary -NoNewWindow -Wait
            Start-Process netsh -ArgumentList $cmdSecondary -NoNewWindow -Wait

            # 3. Redémarrage de la carte uniquement si elle est connectée pour rafraîchir Windows
            if ($adapter.Status -eq 'Up') {
                Restart-NetAdapter -Name $adapterName -Confirm:$false -ErrorAction SilentlyContinue
            }

            $modifiedAdapters += $adapterName
        }

        # 4. Vidage du cache DNS général
        Clear-DnsClientCache -ErrorAction SilentlyContinue

        $listStr = $modifiedAdapters -join ", "
        Write-CustomLog -LogBox $LogBox -Message "SUCCÈS : OpenDNS configuré sur : $listStr" -Color ([System.Drawing.Color]::ForestGreen)

        # 5. Boîte de dialogue Pop-Up d'information
        $msgText = "Les serveurs OpenDNS ont été appliqués avec succès sur les cartes physiques :`n" +
                   "• $($modifiedAdapters -join "`n• ")" + "`n`n" +
                   "Serveurs DNS appliqués :`n" +
                   "• Primaire : 208.67.222.222`n" +
                   "• Secondaire : 208.67.220.220"
        
        [System.Windows.Forms.MessageBox]::Show($msgText, "Configuration DNS Validée", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)

    } catch {
        $errorDetails = $_.Exception.Message
        Write-CustomLog -LogBox $LogBox -Message "ERREUR lors de la configuration DNS : $errorDetails" -Color ([System.Drawing.Color]::Red)
        
        [System.Windows.Forms.MessageBox]::Show("Impossible de modifier les DNS.`nAssurez-vous d'avoir exécuté l'application en tant qu'Administrateur.`n`nDétails : $errorDetails", "Erreur Droits d'accès", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
    }
}

# 6. EXÉCUTION GLOBALE
function Start-AllCustomizations {
    param([System.Windows.Forms.RichTextBox]$LogBox)

    Write-CustomLog -LogBox $LogBox -Message "==========================================" -Color ([System.Drawing.Color]::Blue)
    Write-CustomLog -LogBox $LogBox -Message "LANCEMENT DE LA PERSONNALISATION COMPLÈTE..." -Color ([System.Drawing.Color]::Blue)

    Set-DesktopShortcut -LogBox $LogBox
    Set-DesktopWallpaper -LogBox $LogBox
    Set-UserAvatar -LogBox $LogBox
    Set-WindowsThemeAndColors -LogBox $LogBox

    Write-CustomLog -LogBox $LogBox -Message "==========================================" -Color ([System.Drawing.Color]::ForestGreen)
    Write-CustomLog -LogBox $LogBox -Message "TOUTES LES PERSONNALISATIONS SONT TERMINÉES !" -Color ([System.Drawing.Color]::ForestGreen)
}

# ------------------------------------------
# CONSTRUCTION DE L'ONGLET CUSTOMIZATION
# ------------------------------------------
function Build-TabCustomization {
    param(
        [System.Windows.Forms.TabPage]$TargetTab,
        [System.Windows.Forms.Form]$ParentForm,
        [System.Drawing.Color]$BgColor
    )

    $emojiFontBtn = New-Object System.Drawing.Font("Segoe UI Emoji", 8.5, [System.Drawing.FontStyle]::Bold)
    $emojiFontCard = New-Object System.Drawing.Font("Segoe UI Emoji", 13)

    # Console Log
    $logBox = New-Object System.Windows.Forms.RichTextBox
    $logBox.Location = New-Object System.Drawing.Point(10, 310)
    $logBox.Size = New-Object System.Drawing.Size(840, 115)
    $logBox.BackColor = [System.Drawing.Color]::White
    $logBox.ReadOnly = $true
    $logBox.Font = New-Object System.Drawing.Font("Consolas", 9.5, [System.Drawing.FontStyle]::Regular)
    $TargetTab.Controls.Add($logBox)

    # Barre de progression (alignée avec Software.ps1)
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(10, 435)
    $progressBar.Size = New-Object System.Drawing.Size(840, 20)
    $progressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Continuous
    $TargetTab.Controls.Add($progressBar)

    # --------------------------------------------------
    # PANNEAU HAUT GAUCHE : Personnalisation R2CHAP
    # --------------------------------------------------
    $groupLeft = New-Object System.Windows.Forms.GroupBox
    $groupLeft.Text = " Personnalisation R2CHAP "
    $groupLeft.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $groupLeft.Location = New-Object System.Drawing.Point(10, 10)
    $groupLeft.Size = New-Object System.Drawing.Size(415, 95)
    $TargetTab.Controls.Add($groupLeft)

    $btnAll = New-Object System.Windows.Forms.Button
    $btnAll.Text = "⚡ Appliquer Tout le Thème R2CHAP"
    $btnAll.Font = $emojiFontBtn
    $btnAll.Size = New-Object System.Drawing.Size(390, 30)
    $btnAll.Location = New-Object System.Drawing.Point(12, 22)
    $btnAll.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#6f42c1")
    $btnAll.ForeColor = [System.Drawing.Color]::White
    $btnAll.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnAll.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnAll.Add_Click({ Start-AllCustomizations -LogBox $logBox })
    $groupLeft.Controls.Add($btnAll)

    $btnWeb = New-Object System.Windows.Forms.Button
    $btnWeb.Text = "🌐 Raccourci Web r2chap.be"
    $btnWeb.Font = $emojiFontBtn
    $btnWeb.Size = New-Object System.Drawing.Size(390, 28)
    $btnWeb.Location = New-Object System.Drawing.Point(12, 57)
    $btnWeb.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#17A2B8")
    $btnWeb.ForeColor = [System.Drawing.Color]::White
    $btnWeb.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnWeb.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnWeb.Add_Click({ Set-DesktopShortcut -LogBox $logBox })
    $groupLeft.Controls.Add($btnWeb)

    # --------------------------------------------------
    # PANNEAU HAUT DROITE : Réseau & Multimédia
    # --------------------------------------------------
    $groupRight = New-Object System.Windows.Forms.GroupBox
    $groupRight.Text = " Réseau & Multimédia WinGet "
    $groupRight.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $groupRight.Location = New-Object System.Drawing.Point(435, 10)
    $groupRight.Size = New-Object System.Drawing.Size(415, 95)
    $TargetTab.Controls.Add($groupRight)

    $btnDNS = New-Object System.Windows.Forms.Button
    $btnDNS.Text = "🛡️ Activer OpenDNS (208.67.222.222)"
    $btnDNS.Font = $emojiFontBtn
    $btnDNS.Size = New-Object System.Drawing.Size(390, 28)
    $btnDNS.Location = New-Object System.Drawing.Point(12, 22)
    $btnDNS.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#28A745")
    $btnDNS.ForeColor = [System.Drawing.Color]::White
    $btnDNS.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnDNS.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnDNS.Add_Click({ Set-OpenDNSConfig -LogBox $logBox })
    $groupRight.Controls.Add($btnDNS)

    # Variables partagées pour les clics
    $pBar = $progressBar
    $lBox = $logBox
    $pForm = $ParentForm
    $wingetInstallBlock = $script:InvokeWingetInstallBlock

    # Bouton Kodi
    $btnKodi = New-Object System.Windows.Forms.Button
    $btnKodi.Text = "🎬 Installer Kodi"
    $btnKodi.Font = $emojiFontBtn
    $btnKodi.Size = New-Object System.Drawing.Size(190, 28)
    $btnKodi.Location = New-Object System.Drawing.Point(12, 57)
    $btnKodi.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#007ACC")
    $btnKodi.ForeColor = [System.Drawing.Color]::White
    $btnKodi.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnKodi.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnKodi.Add_Click({
        & $wingetInstallBlock -AppName "Kodi" -AppId "XBMCFoundation.Kodi" -LogBox $lBox -ProgressBar $pBar -ParentForm $pForm
    }.GetNewClosure())
    $groupRight.Controls.Add($btnKodi)

    # Bouton Romstation
    $btnRomstation = New-Object System.Windows.Forms.Button
    $btnRomstation.Text = "🎮 Installer RomStation"
    $btnRomstation.Font = $emojiFontBtn
    $btnRomstation.Size = New-Object System.Drawing.Size(192, 28)
    $btnRomstation.Location = New-Object System.Drawing.Point(210, 57)
    $btnRomstation.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#FD7E14")
    $btnRomstation.ForeColor = [System.Drawing.Color]::White
    $btnRomstation.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnRomstation.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnRomstation.Add_Click({
        & $wingetInstallBlock -AppName "Romstation" -AppId "" -LogBox $lBox -ProgressBar $pBar -ParentForm $pForm
    }.GetNewClosure())
    $groupRight.Controls.Add($btnRomstation)

    # --------------------------------------------------
    # PANNEAU BAS : Cartes Visuelles Individuelles
    # --------------------------------------------------
    $lblCards = New-Object System.Windows.Forms.Label
    $lblCards.Text = "Paramètres système & visuels :"
    $lblCards.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $lblCards.Location = New-Object System.Drawing.Point(10, 112)
    $lblCards.Size = New-Object System.Drawing.Size(350, 20)
    $TargetTab.Controls.Add($lblCards)

    $cardsPanel = New-Object System.Windows.Forms.Panel
    $cardsPanel.Location = New-Object System.Drawing.Point(10, 135)
    $cardsPanel.Size = New-Object System.Drawing.Size(840, 165)
    $cardsPanel.AutoScroll = $true
    $TargetTab.Controls.Add($cardsPanel)

    $customList = @(
        @{ Title = "Fond d'écran"; Subtitle = "Applique wallpaper.png (Local/USB)"; Icon = "🖼️"; Action = { Set-DesktopWallpaper -LogBox $logBox } },
        @{ Title = "Avatar Utilisateur"; Subtitle = "Applique user_avatar.png"; Icon = "👤"; Action = { Set-UserAvatar -LogBox $logBox } },
        @{ Title = "Thèmes & Couleurs"; Subtitle = "Windows Sombre / Fenêtres Claires"; Icon = "🎨"; Action = { Set-WindowsThemeAndColors -LogBox $logBox } }
    )

    $colCount = 3
    $cardWidth = 265
    $cardHeight = 70
    $spacing = 10

    for ($i = 0; $i -lt $customList.Count; $i++) {
        $item = $customList[$i]
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
        $lblIcon.Location = New-Object System.Drawing.Point(8, 12)
        $lblIcon.Size = New-Object System.Drawing.Size(40, 40)
        $lblIcon.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
        $card.Controls.Add($lblIcon)

        $lblName = New-Object System.Windows.Forms.Label
        $lblName.Text = $item.Title
        $lblName.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
        $lblName.Location = New-Object System.Drawing.Point(52, 12)
        $lblName.Size = New-Object System.Drawing.Size(200, 20)

        $lblSub = New-Object System.Windows.Forms.Label
        $lblSub.Text = $item.Subtitle
        $lblSub.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Italic)
        $lblSub.Location = New-Object System.Drawing.Point(52, 34)
        $lblSub.Size = New-Object System.Drawing.Size(200, 28)
        $lblSub.ForeColor = [System.Drawing.Color]::DimGray

        $card.Controls.Add($lblName)
        $card.Controls.Add($lblSub)

        $clickEvent = $item.Action
        $card.Add_Click($clickEvent)
        $lblIcon.Add_Click($clickEvent)
        $lblName.Add_Click($clickEvent)
        $lblSub.Add_Click($clickEvent)

        $cardsPanel.Controls.Add($card)
    }
}