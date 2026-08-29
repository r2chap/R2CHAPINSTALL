# ==========================================
# R2CHAP INSTALL - Outil Nomade de Déploiement
# Version : v0.1
# Dépôt : https://github.com/r2chap/R2CHAPINSTALL
# ==========================================

$ScriptVersion = "v0.1"
$UpdateUrl     = "https://raw.githubusercontent.com/r2chap/R2CHAPINSTALL/main/R2ChapInstall.ps1"

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Élévation de privilèges Admin automatique
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$LocalTargetDir = "C:\r2chap"

# ------------------------------------------
# 0. DÉPLOIEMENT PERMANENT DES ASSETS DANS C:\r2chap
# ------------------------------------------
function Sync-LocalAssets {
    if (-not (Test-Path $LocalTargetDir)) {
        New-Item -ItemType Directory -Path $LocalTargetDir -Force | Out-Null
    }

    $assetSource = Join-Path $ScriptDir "assets"
    if (Test-Path $assetSource) {
        Copy-Item -Path "$assetSource\*" -Destination $LocalTargetDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
Sync-LocalAssets

# Paths locaux de référence
$localWallpaper = Join-Path $LocalTargetDir "wallpaper.jpg"
$localAvatar    = Join-Path $LocalTargetDir "user_avatar.png"
$localIcon      = Join-Path $LocalTargetDir "Logo.ico"
$localLogo      = Join-Path $LocalTargetDir "Logo.png"

# ------------------------------------------
# GESTION DES LOGS ET PROGRESSION
# ------------------------------------------

function Log-Message ($msg) {
    if ($global:txtLog) {
        $startPos = $global:txtLog.TextLength
        $timestampedMsg = "[$((Get-Date).ToString('HH:mm:ss'))] $msg`r`n"
        
        $global:txtLog.AppendText($timestampedMsg)
        $global:txtLog.Select($startPos, $timestampedMsg.Length)

        if ($msg -match "\[ERREUR\]" -or $msg -match "\[ATTENTION\]" -or $msg -match "Échec" -or $msg -match "CRITIQUE") {
            $global:txtLog.SelectionColor = [System.Drawing.Color]::FromArgb(255, 85, 85) # Rouge
        } else {
            $global:txtLog.SelectionColor = [System.Drawing.Color]::FromArgb(0, 255, 128) # Vert
        }

        $global:txtLog.SelectionLength = 0
        $global:txtLog.SelectionStart = $global:txtLog.Text.Length
        $global:txtLog.ScrollToCaret()
        [System.Windows.Forms.Application]::DoEvents()
    }
    Write-Host $msg
}

function Set-Progress ($percent) {
    if ($global:progressBar) {
        $global:progressBar.Value = [math]::Min(100, [math]::Max(0, [int]$percent))
        [System.Windows.Forms.Application]::DoEvents()
    }
}

# ------------------------------------------
# FONCTION DE MISE À JOUR DEPUIS GITHUB
# ------------------------------------------
function Update-Script {
    Log-Message "-> Vérification des mises à jour sur GitHub (Version locale : $ScriptVersion)..."
    
    try {
        $tempScriptPath = Join-Path $env:TEMP "R2ChapInstall_new.ps1"
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $UpdateUrl -OutFile $tempScriptPath -UseBasicParsing -ErrorAction Stop
        
        $newContent = Get-Content $tempScriptPath -Raw
        if ($newContent -match '\$ScriptVersion\s*=\s*"([^"]+)"') {
            $remoteVersion = $matches[1]
            if ($remoteVersion -ne $ScriptVersion) {
                Log-Message "   [INFO] Nouvelle version disponible sur GitHub : $remoteVersion"
                
                # Remplacement du script local
                Copy-Item -Path $tempScriptPath -Destination $PSCommandPath -Force
                Remove-Item -Path $tempScriptPath -Force -ErrorAction SilentlyContinue
                
                Log-Message "   [OK] Script mis à jour vers la $remoteVersion. Redémarrage..."
                [System.Windows.Forms.MessageBox]::Show("Script mis à jour vers la version $remoteVersion ! Le script va redémarrer.", "Mise à jour réussie", "OK", "Information")
                
                # Relance automatique de la nouvelle version
                Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
                if ($global:form) { $global:form.Close() }
                return
            } else {
                Log-Message "   [OK] Vous possédez déjà la version la plus récente ($ScriptVersion)."
            }
        } else {
            Log-Message "   [ATTENTION] Impossible de lire le numéro de version sur le dépôt GitHub."
        }
        Remove-Item -Path $tempScriptPath -Force -ErrorAction SilentlyContinue
    } catch {
        Log-Message "   [ERREUR] Impossible de contacter GitHub : $_"
    }
}

# ------------------------------------------
# FONCTIONS MODULES INDIVIDUELLES
# ------------------------------------------

# 1. Pilotes
function Install-Drivers {
    Log-Message "-> Installation des pilotes (.inf)..."
    $driverPath = Join-Path $ScriptDir "drivers"
    if (Test-Path $driverPath) {
        pnputil.exe /add-driver "$driverPath\*.inf" /subdirs /install | Out-Null
        Log-Message "   [OK] Pilotes installés."
    } else {
        Log-Message "   [ATTENTION] Dossier '$driverPath' introuvable."
    }
}

# 2. Fond d'écran
function Set-Wallpaper {
    Log-Message "-> Application du fond d'écran depuis $localWallpaper..."
    if (Test-Path $localWallpaper) {
        $code = @'
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
'@
        Add-Type -TypeDefinition $code -ErrorAction SilentlyContinue
        [Wallpaper]::SystemParametersInfo(20, 0, $localWallpaper, 3)
        Log-Message "   [OK] Fond d'écran appliqué."
    } else {
        Log-Message "   [ERREUR] Image '$localWallpaper' introuvable."
    }
}

# 3. Photo de profil
function Set-UserAvatar {
    Log-Message "-> Application de la photo de profil depuis $localAvatar..."
    if (Test-Path $localAvatar) {
        $accountPicDir = "$env:APPDATA\Microsoft\Windows\AccountPictures"
        if (-not (Test-Path $accountPicDir)) { New-Item -ItemType Directory -Path $accountPicDir | Out-Null }
        Copy-Item -Path $localAvatar -Destination "$accountPicDir\user.png" -Force
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\AccountPicture" -Name "SourceId" -Value "$accountPicDir\user.png" -ErrorAction SilentlyContinue
        Log-Message "   [OK] Photo de profil configurée."
    } else {
        Log-Message "   [ERREUR] Image '$localAvatar' introuvable."
    }
}

# 4. Raccourci Web sur le bureau
function Set-WebShortcut {
    Log-Message "-> Création du raccourci Web r2chap.be sur le Bureau..."
    try {
        $desktopPath = [System.Environment]::GetFolderPath("Desktop")
        $shortcutPath = Join-Path $desktopPath "R2Chap.lnk"
        
        $wshShell = New-Object -ComObject WScript.Shell
        $shortcut = $wshShell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = "https://r2chap.be"
        
        if (Test-Path $localIcon) {
            $shortcut.IconLocation = "$localIcon,0"
        }
        $shortcut.Save()
        Log-Message "   [OK] Raccourci créé sur le Bureau avec l'icône personnalisée."
    } catch {
        Log-Message "   [ERREUR] Échec de création du raccourci : $_"
    }
}

# 5. Thème Hybride & Couleur d'accentuation automatique
function Set-PersonalizationTheme {
    Log-Message "-> Personnalisation du Thème (Windows Sombre / Apps Claire / Accentuation Auto)..."
    $regPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"
    $dwmPath = "HKCU:\Software\Microsoft\Windows\DWM"

    Set-ItemProperty -Path $regPath -Name "SystemUsesLightTheme" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $regPath -Name "AppsUseLightTheme" -Value 1 -ErrorAction SilentlyContinue

    Set-ItemProperty -Path $dwmPath -Name "ColorPrevalence" -Value 1 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "AutoColorization" -Value 1 -ErrorAction SilentlyContinue
    
    RUNDLL32.EXE USER32.DLL,UpdatePerUserSystemParameters
    Log-Message "   [OK] Thème hybride et couleur d'accentuation automatique appliqués."
}

# 6. Applications Winget
function Install-Applications ($baseProgress = 0, $progressWeight = 100) {
    Log-Message "-> Déploiement des applications Winget..."

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Log-Message "   [ERREUR CRITIQUE] Winget non présent sur cette machine."
        return
    }

    Log-Message "   Mise à jour des sources Winget..."
    winget source update --silent | Out-Null

    $appList = @(
        @{ Name = "Opera Browser";       Id = "Opera.Opera" },
        @{ Name = "Google Chrome";      Id = "Google.Chrome" },
        @{ Name = "Mozilla Firefox";     Id = "Mozilla.Firefox" },
        @{ Name = "Notepad++";           Id = "Notepad++.Notepad++" },
        @{ Name = "7-Zip";               Id = "7zip.7zip" },
        @{ Name = "VLC Media Player";    Id = "VideoLAN.VLC" },
        @{ Name = "Mozilla Thunderbird"; Id = "Mozilla.Thunderbird" },
        @{ Name = "GIMP";                Id = "GIMP.GIMP" },
        @{ Name = "LibreOffice";         Id = "TheDocumentFoundation.LibreOffice" },
        @{ Name = "Paint.NET";           Id = "dotPDNLLC.Paint.NET" },
        @{ Name = "Foxit Reader";        Id = "Foxit.FoxitReader" },
        @{ Name = "eID Belgique";        Id = "BelgianGovernment.beID" }
    )

    $step = $progressWeight / $appList.Count
    $currentProg = $baseProgress

    foreach ($app in $appList) {
        Log-Message "   Installation de $($app.Name)..."
        
        $p = Start-Process winget -ArgumentList "install --id $($app.Id) --silent --accept-package-agreements --accept-source-agreements" -Wait -NoNewWindow -PassThru
        
        if ($p.ExitCode -eq -1978335212) {
            Log-Message "   [RECHERCHE] Recherche alternative par nom pour $($app.Name)..."
            $p = Start-Process winget -ArgumentList "install --name `"$($app.Name)`" --silent --accept-package-agreements --accept-source-agreements" -Wait -NoNewWindow -PassThru
        }

        if ($p.ExitCode -eq 0 -or $p.ExitCode -eq -1978335189) {
            Log-Message "   [OK] $($app.Name) est prêt."
        } else {
            Log-Message "   [ATTENTION] Code retour $($p.ExitCode) pour $($app.Name)."
        }
        
        $currentProg += $step
        Set-Progress $currentProg
    }
    Log-Message "   [OK] Fin du déploiement des applications."
}

# 7. Blocage des applications non essentielles au démarrage
function Disable-StartupApps {
    Log-Message "-> Désactivation des applications non essentielles au démarrage..."
    
    $runKeys = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
    )

    $appsToDisable = @("OneDrive", "Opera", "GoogleChromeAutoLaunch", "Chrome", "Firefox", "Mozilla Firefox")

    foreach ($key in $runKeys) {
        if (Test-Path $key) {
            foreach ($appName in $appsToDisable) {
                $prop = Get-ItemProperty -Path $key -Name $appName -ErrorAction SilentlyContinue
                if ($prop) {
                    Remove-ItemProperty -Path $key -Name $appName -ErrorAction SilentlyContinue
                    Log-Message "   * Désactivé dans le registre ($key): $appName"
                }
            }
        }
    }

    $approvedKeys = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"
    )

    $disabledValue = [byte[]](0x03,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00)

    foreach ($key in $approvedKeys) {
        if (Test-Path $key) {
            foreach ($appName in $appsToDisable) {
                Set-ItemProperty -Path $key -Name $appName -Value $disabledValue -Type Binary -ErrorAction SilentlyContinue
            }
        }
    }

    Get-Process -Name "OneDrive", "Opera", "chrome", "firefox" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

    Log-Message "   [OK] Démarrage automatique bloqué pour Opera, Chrome, Firefox et OneDrive."
}

# 8. Essential Tweaks & Configuration des Effets Visuels
function Apply-EssentialTweaks {
    Log-Message "-> Application des Essential Tweaks..."

    if ($global:chkTelemetry.Checked) {
        Log-Message "   * Désactivation Télémétrie..."
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0 -ErrorAction SilentlyContinue
        Stop-Service -Name "DiagTrack" -ErrorAction SilentlyContinue
        Set-Service -Name "DiagTrack" -StartupType Disabled -ErrorAction SilentlyContinue
    }

    if ($global:chkActivity.Checked) {
        Log-Message "   * Désactivation Historique d'activité..."
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableActivityFeed" -Value 0 -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "PublishUserActivities" -Value 0 -ErrorAction SilentlyContinue
    }

    if ($global:chkShowExt.Checked) {
        Log-Message "   * Affichage des extensions de fichiers..."
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0 -ErrorAction SilentlyContinue
    }

    if ($global:chkGameMode.Checked) {
        Log-Message "   * Activation Game Mode..."
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\GameBar" -Name "AllowAutoGameMode" -Value 1 -ErrorAction SilentlyContinue
    }

    if ($global:chkPowerPlan.Checked) {
        Log-Message "   * Activation Plan Performance Élevée..."
        powercfg /s 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
    }

    if ($global:chkVisualFX.Checked) {
        Log-Message "   * Configuration des Effets Visuels sur mesure (Performances)..."
        
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualFX" -Name "VisualFXSetting" -Value 3 -ErrorAction SilentlyContinue
        
        $desktopKey = "HKCU:\Control Panel\Desktop"
        $advancedKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

        Set-ItemProperty -Path $desktopKey -Name "UserPreferencesMask" -Value ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $desktopKey -Name "DragFullWindows" -Value "1" -ErrorAction SilentlyContinue 
        Set-ItemProperty -Path $desktopKey -Name "FontSmoothing" -Value "2" -ErrorAction SilentlyContinue   

        Set-ItemProperty -Path $advancedKey -Name "IconsOnly" -Value 0 -ErrorAction SilentlyContinue           
        Set-ItemProperty -Path $advancedKey -Name "ListviewAlphaSelect" -Value 1 -ErrorAction SilentlyContinue 
        Set-ItemProperty -Path $advancedKey -Name "TaskbarAnimations" -Value 0 -ErrorAction SilentlyContinue   
        Set-ItemProperty -Path $advancedKey -Name "ListviewShadow" -Value 0 -ErrorAction SilentlyContinue       

        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\DWM" -Name "EnableAeroPeek" -Value 0 -ErrorAction SilentlyContinue
        
        Log-Message "     [OK] Effets visuels personnalisés appliqués."
    }

    Disable-StartupApps
    Log-Message "   [OK] Tweaks appliqués."
}

# 9. Nettoyage Système & Effacement Historiques/Recommandations
function Start-SystemCleanup {
    Log-Message "-> Début du nettoyage complet du système..."
    Set-Progress 10

    Log-Message "   Purge des fichiers temporaires (User & System)..."
    $tempFolders = @($env:TEMP, "C:\Windows\Temp", "C:\Windows\Prefetch")
    foreach ($folder in $tempFolders) {
        if (Test-Path $folder) {
            Get-ChildItem -Path $folder -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    Set-Progress 40

    Log-Message "   Vidage de la Corbeille..."
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    Set-Progress 60

    Log-Message "   Effacement de l'historique des fichiers récents et JumpLists..."
    $recentPath = "$env:APPDATA\Microsoft\Windows\Recent"
    if (Test-Path $recentPath) {
        Get-ChildItem -Path $recentPath -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
    Set-Progress 80

    Log-Message "   Désactivation de la section Recommandés du Menu Démarrer..."
    $advReg = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-ItemProperty -Path $advReg -Name "Start_TrackDocs" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $advReg -Name "Start_TrackProgs" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "HideRecommendedSection" -Value 1 -ErrorAction SilentlyContinue

    Set-Progress 100
    Log-Message "   [OK] Nettoyage et purge des historiques terminés avec succès."
}

# 10. Gestion Windows Update
function Invoke-WindowsUpdates {
    Log-Message "-> Vérification et installation des mises à jour Windows..."
    
    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Log-Message "   Installation du module PSWindowsUpdate..."
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ErrorAction SilentlyContinue
        Install-Module -Name PSWindowsUpdate -Force -Confirm:$false -Scope CurrentUser -ErrorAction SilentlyContinue
    }

    Import-Module PSWindowsUpdate -ErrorAction SilentlyContinue

    if (Get-Command Get-WindowsUpdate -ErrorAction SilentlyContinue) {
        Log-Message "   Recherche des mises à jour en cours..."
        $updates = Get-WindowsUpdate -ErrorAction SilentlyContinue
        
        if ($updates) {
            Log-Message "   $($updates.Count) mise(s) à jour trouvée(s). Installation..."
            
            $runOnceKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
            $cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
            Set-ItemProperty -Path $runOnceKey -Name "R2ChapResume" -Value $cmd -ErrorAction SilentlyContinue
            Log-Message "   [INFO] Reprise automatique du script configurée après redémarrage."

            Install-WindowsUpdate -AcceptAll -AutoReboot -Confirm:$false
        } else {
            Log-Message "   [OK] Le système est déjà entièrement à jour."
        }
    } else {
        Log-Message "   [ATTENTION] Utilisation de USOClient pour déclencher la mise à jour..."
        usoclient StartInteractiveScan
    }
}

# ------------------------------------------
# FONCTION TOTAL CONVERSION
# ------------------------------------------
function Run-TotalConversion {
    $confirm = [System.Windows.Forms.MessageBox]::Show(
        "Lancer la Total Conversion ?`nToutes les opérations automatisées vont s'exécuter à la suite.", 
        "R2Chap Total Conversion", 
        "YesNo", 
        "Question"
    )

    if ($confirm -eq "Yes") {
        Set-Progress 0
        Log-Message "=================================================="
        Log-Message "    DÉMARRAGE DE LA TOTAL CONVERSION (0%)"
        Log-Message "=================================================="

        Log-Message "[Étape 1/8] Installation des pilotes..."
        Install-Drivers
        Set-Progress 10

        Log-Message "[Étape 2/8] Configuration des visuels locaux (C:\r2chap)..."
        Set-Wallpaper
        Set-UserAvatar
        Set-Progress 20

        Log-Message "[Étape 3/8] Application du Thème Hybride & Couleur d'accentuation..."
        Set-PersonalizationTheme
        Set-Progress 30

        Log-Message "[Étape 4/8] Création du raccourci Web r2chap.be..."
        Set-WebShortcut
        Set-Progress 35

        Log-Message "[Étape 5/8] Installation des logiciels..."
        Install-Applications -baseProgress 35 -progressWeight 35
        Set-Progress 70

        Log-Message "[Étape 6/8] Désactivation des applications non essentielles au démarrage..."
        Disable-StartupApps
        Set-Progress 80

        Log-Message "[Étape 7/8] Optimisation du système (Tweaks & Effets visuels)..."
        Apply-EssentialTweaks
        Set-Progress 90

        Log-Message "[Étape 8/8] Purge des fichiers temporaires & historiques..."
        Start-SystemCleanup
        Set-Progress 100

        Log-Message "=================================================="
        Log-Message "    TOTAL CONVERSION TERMINÉE AVEC SUCCÈS (100%) !"
        Log-Message "=================================================="
        
        [System.Windows.Forms.MessageBox]::Show("La Total Conversion est terminée avec succès !", "Succès", "OK", "Information")
    }
}

# ------------------------------------------
# INTERFACE GRAPHIQUE (GUI - WINFORMS DARK THEME)
# ------------------------------------------

$bgDarkColor = [System.Drawing.ColorTranslator]::FromHtml("#1E2726")
$purpleColor = [System.Drawing.ColorTranslator]::FromHtml("#A40BF2")

$global:form = New-Object System.Windows.Forms.Form
$global:form.Text = "R2Chap Install - Windows Deployer $ScriptVersion"
$global:form.Size = New-Object System.Drawing.Size(740, 720)
$global:form.StartPosition = "CenterScreen"
$global:form.FormBorderStyle = "FixedSingle"
$global:form.MaximizeBox = $False
$global:form.BackColor = $bgDarkColor
$global:form.ForeColor = [System.Drawing.Color]::White

# Logo (PNG HD prioritaire)
if (Test-Path $localLogo) {
    $pictureBox = New-Object System.Windows.Forms.PictureBox
    $pictureBox.Image = [System.Drawing.Image]::FromFile($localLogo)
    $pictureBox.Location = New-Object System.Drawing.Point(20, 15)
    $pictureBox.Size = New-Object System.Drawing.Size(65, 65)
    $pictureBox.SizeMode = "Zoom"
    $global:form.Controls.Add($pictureBox)
} 
elseif (Test-Path $localIcon) {
    $pictureBox = New-Object System.Windows.Forms.PictureBox
    $pictureBox.Image = (New-Object System.Drawing.Icon($localIcon, 64, 64)).ToBitmap()
    $pictureBox.Location = New-Object System.Drawing.Point(20, 15)
    $pictureBox.Size = New-Object System.Drawing.Size(65, 65)
    $pictureBox.SizeMode = "Zoom"
    $global:form.Controls.Add($pictureBox)
}

# En-tête avec numéro de version
$label = New-Object System.Windows.Forms.Label
$label.Text = "R2CHAP INSTALL $ScriptVersion"
$label.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$label.ForeColor = [System.Drawing.Color]::White
$label.Location = New-Object System.Drawing.Point(95, 18)
$label.Size = New-Object System.Drawing.Size(350, 30)
$global:form.Controls.Add($label)

$subLabel = New-Object System.Windows.Forms.Label
$subLabel.Text = "Assistant nomade de déploiement et maintenance Windows"
$subLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
$subLabel.ForeColor = [System.Drawing.Color]::LightGray
$subLabel.Location = New-Object System.Drawing.Point(95, 48)
$subLabel.Size = New-Object System.Drawing.Size(380, 20)
$global:form.Controls.Add($subLabel)

# Bouton Total Conversion (#A40BF2)
$btnTotal = New-Object System.Windows.Forms.Button
$btnTotal.Text = "⚡ TOTAL CONVERSION"
$btnTotal.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$btnTotal.Location = New-Object System.Drawing.Point(510, 18)
$btnTotal.Size = New-Object System.Drawing.Size(190, 50)
$btnTotal.FlatStyle = "Flat"
$btnTotal.FlatAppearance.BorderSize = 0
$btnTotal.BackColor = $purpleColor
$btnTotal.ForeColor = [System.Drawing.Color]::White
$btnTotal.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnTotal.Add_Click({ Run-TotalConversion })
$global:form.Controls.Add($btnTotal)

# Groupes d'actions
$grpActions = New-Object System.Windows.Forms.GroupBox
$grpActions.Text = " Actions Unitaires & Maintenance "
$grpActions.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$grpActions.ForeColor = [System.Drawing.Color]::White
$grpActions.Location = New-Object System.Drawing.Point(20, 90)
$grpActions.Size = New-Object System.Drawing.Size(340, 310)
$grpActions.BackColor = $bgDarkColor
$global:form.Controls.Add($grpActions)

function Add-ActionButton ($text, $yPos, $scriptBlock) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $text
    $btn.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
    $btn.Location = New-Object System.Drawing.Point(15, $yPos)
    $btn.Size = New-Object System.Drawing.Size(310, 34)
    $btn.FlatStyle = "Flat"
    $btn.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(60, 75, 75)
    $btn.BackColor = [System.Drawing.Color]::FromArgb(40, 52, 51)
    $btn.ForeColor = [System.Drawing.Color]::White
    $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btn.Add_Click($scriptBlock)
    $grpActions.Controls.Add($btn)
}

Add-ActionButton "1. Installer les Pilotes" 25 { Set-Progress 0; Install-Drivers; Set-Progress 100 }
Add-ActionButton "2. Fond d'Écran, Avatar & Thème" 65 { Set-Progress 0; Set-Wallpaper; Set-UserAvatar; Set-PersonalizationTheme; Set-Progress 100 }
Add-ActionButton "3. Créer le Raccourci r2chap.be" 105 { Set-Progress 0; Set-WebShortcut; Set-Progress 100 }
Add-ActionButton "4. Installer Apps (Winget)" 145 { Set-Progress 0; Install-Applications -baseProgress 0 -progressWeight 100; Set-Progress 100 }
Add-ActionButton "5. Bloquer Démarrage Auto Applis" 185 { Set-Progress 0; Disable-StartupApps; Set-Progress 100 }
Add-ActionButton "6. Mises à jour Windows Update" 225 { Set-Progress 0; Invoke-WindowsUpdates; Set-Progress 100 }
Add-ActionButton "7. Nettoyage Temp & Purge Historiques" 265 { Set-Progress 0; Start-SystemCleanup; Set-Progress 100 }

# Groupe Essential Tweaks
$grpTweaks = New-Object System.Windows.Forms.GroupBox
$grpTweaks.Text = " Options Essential Tweaks "
$grpTweaks.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$grpTweaks.ForeColor = [System.Drawing.Color]::White
$grpTweaks.Location = New-Object System.Drawing.Point(380, 90)
$grpTweaks.Size = New-Object System.Drawing.Size(320, 310)
$grpTweaks.BackColor = $bgDarkColor
$global:form.Controls.Add($grpTweaks)

function Create-Checkbox ($text, $yPos, $checked=$true) {
    $chk = New-Object System.Windows.Forms.CheckBox
    $chk.Text = $text
    $chk.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
    $chk.ForeColor = [System.Drawing.Color]::White
    $chk.Location = New-Object System.Drawing.Point(15, $yPos)
    $chk.Size = New-Object System.Drawing.Size(290, 25)
    $chk.Checked = $checked
    $grpTweaks.Controls.Add($chk)
    return $chk
}

$global:chkTelemetry = Create-Checkbox "Désactiver la Télémétrie" 30
$global:chkActivity  = Create-Checkbox "Désactiver Historique d'Activité" 70
$global:chkShowExt   = Create-Checkbox "Afficher extensions de fichiers" 110
$global:chkGameMode  = Create-Checkbox "Activer le Mode Jeu (Game Mode)" 150
$global:chkPowerPlan = Create-Checkbox "Activer Plan Alimentation Élevée" 190
$global:chkVisualFX  = Create-Checkbox "Optimiser les effets visuels (Performances)" 230

# Console & Progression
$lblProg = New-Object System.Windows.Forms.Label
$lblProg.Text = "Journal d'activité et progression :"
$lblProg.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$lblProg.ForeColor = [System.Drawing.Color]::White
$lblProg.Location = New-Object System.Drawing.Point(20, 415)
$lblProg.Size = New-Object System.Drawing.Size(250, 20)
$global:form.Controls.Add($lblProg)

$global:progressBar = New-Object System.Windows.Forms.ProgressBar
$global:progressBar.Location = New-Object System.Drawing.Point(20, 438)
$global:progressBar.Size = New-Object System.Drawing.Size(680, 20)
$global:progressBar.Style = "Continuous"
$global:form.Controls.Add($global:progressBar)

# RichTextBox
$global:txtLog = New-Object System.Windows.Forms.RichTextBox
$global:txtLog.Location = New-Object System.Drawing.Point(20, 468)
$global:txtLog.Size = New-Object System.Drawing.Size(680, 155)
$global:txtLog.ReadOnly = $True
$global:txtLog.ScrollBars = "Vertical"
$global:txtLog.Font = New-Object System.Drawing.Font("Consolas", 8.5)
$global:txtLog.BackColor = [System.Drawing.Color]::FromArgb(15, 20, 20)
$global:txtLog.BorderStyle = "FixedSingle"
$global:form.Controls.Add($global:txtLog)

# Bouton Mettre à jour depuis GitHub
$btnUpdate = New-Object System.Windows.Forms.Button
$btnUpdate.Text = "🔄 Mettre à jour le script"
$btnUpdate.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnUpdate.Location = New-Object System.Drawing.Point(20, 633)
$btnUpdate.Size = New-Object System.Drawing.Size(190, 35)
$btnUpdate.FlatStyle = "Flat"
$btnUpdate.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(60, 75, 75)
$btnUpdate.BackColor = [System.Drawing.Color]::FromArgb(40, 52, 51)
$btnUpdate.ForeColor = [System.Drawing.Color]::White
$btnUpdate.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnUpdate.Add_Click({ Update-Script })
$global:form.Controls.Add($btnUpdate)

# Bouton Quitter (Rouge)
$btnExit = New-Object System.Windows.Forms.Button
$btnExit.Text = "Quitter"
$btnExit.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
$btnExit.Location = New-Object System.Drawing.Point(560, 633)
$btnExit.Size = New-Object System.Drawing.Size(140, 35)
$btnExit.FlatStyle = "Flat"
$btnExit.FlatAppearance.BorderSize = 0
$btnExit.BackColor = [System.Drawing.Color]::FromArgb(220, 53, 69)
$btnExit.ForeColor = [System.Drawing.Color]::White
$btnExit.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnExit.Add_Click({ $global:form.Close() })
$global:form.Controls.Add($btnExit)

Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce" -Name "R2ChapResume" -ErrorAction SilentlyContinue

Log-Message "Application R2Chap Install ($ScriptVersion) initialisée."
Log-Message "Les assets ont été synchronisés dans C:\r2chap."
Log-Message "Prêt pour les actions unitaires ou la 'Total Conversion'."

$global:form.ShowDialog() | Out-Null