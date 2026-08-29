# ==========================================
# R2CHAP INSTALL - Main GUI Launcher
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

# ------------------------------------------
# 1. CHARGEMENT AUTOMATIQUE DES MODULES
# ------------------------------------------
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ModuleDir = Join-Path $ScriptDir "modules"

if (Test-Path $ModuleDir) {
    Get-ChildItem -Path $ModuleDir -Filter "*.ps1" | ForEach-Object {
        try {
            . $_.FullName
        } catch {
            Write-Host "Erreur au chargement du module $($_.Name) : $_" -ForegroundColor Red
        }
    }
}

$LocalTargetDir = "C:\r2chap"
$localLogo      = Join-Path $LocalTargetDir "Logo.png"

# Chemins des images dans le dossier assets
$assetsDir       = Join-Path $ScriptDir "assets"
$imgUpdatePath   = Join-Path $assetsDir "mise-a-jour-du-systeme.png"
$imgSettingsPath = Join-Path $assetsDir "parametres.png"

# ------------------------------------------
# HELPER : REDIMENSIONNEMENT DES IMAGES (PNG)
# ------------------------------------------
function Get-ResizedImage ($filePath, $width, $height) {
    if (Test-Path $filePath) {
        try {
            $origImg = [System.Drawing.Image]::FromFile($filePath)
            $bmp = New-Object System.Drawing.Bitmap([int]$width, [int]$height)
            $graph = [System.Drawing.Graphics]::FromImage($bmp)
            $graph.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graph.DrawImage($origImg, 0, 0, [int]$width, [int]$height)
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
# FONCTIONS DES BOUTONS EN-TÊTE ET ACTIONS
# ------------------------------------------
function Check-AppUpdate {
    try {
        $tempScriptPath = Join-Path $env:TEMP "R2ChapInstall_new.ps1"
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $UpdateUrl -OutFile $tempScriptPath -UseBasicParsing -ErrorAction Stop
        
        $newContent = Get-Content $tempScriptPath -Raw
        if ($newContent -match '\$ScriptVersion\s*=\s*"([^"]+)"') {
            $remoteVersion = $matches[1]
            if ($remoteVersion -ne $ScriptVersion) {
                $dialogResult = [System.Windows.Forms.MessageBox]::Show(
                    "Une nouvelle version ($remoteVersion) est disponible sur GitHub !`n`nVoulez-vous mettre à jour le script maintenant ?", 
                    "Mise à jour disponible", 
                    "YesNo", 
                    "Information"
                )
                if ($dialogResult -eq "Yes") {
                    Copy-Item -Path $tempScriptPath -Destination $PSCommandPath -Force
                    Remove-Item -Path $tempScriptPath -Force -ErrorAction SilentlyContinue
                    [System.Windows.Forms.MessageBox]::Show("Mise à jour réussie vers la $remoteVersion ! Le script va redémarrer.", "OK", "OK", "Information")
                    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
                    $form.Close()
                    return
                }
            } else {
                [System.Windows.Forms.MessageBox]::Show("Vous possédez déjà la version la plus récente ($ScriptVersion).", "À jour", "OK", "Information")
            }
        }
        Remove-Item -Path $tempScriptPath -Force -ErrorAction SilentlyContinue
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Impossible de vérifier les mises à jour : $_", "Erreur réseau", "OK", "Error")
    }
}

function Open-SettingsDialog {
    [System.Windows.Forms.MessageBox]::Show(
        "Fenêtre des paramètres de l'application R2Chap Install.`n(Vous pourrez y ajouter la configuration des dossiers, clés d'API ou préférences).", 
        "Paramètres", 
        "OK", 
        "Information"
    )
}

function Start-TotalConversion {
    $result = [System.Windows.Forms.MessageBox]::Show(
        "Êtes-vous sûr de vouloir lancer la Total Conversion ?`n`nToutes les opérations configurées seront exécutées séquentiellement.", 
        "Confirmation Total Conversion", 
        "YesNo", 
        "Warning"
    )
    if ($result -eq "Yes") {
        [System.Windows.Forms.MessageBox]::Show("Lancement du processus...", "Total Conversion", "OK", "Information")
    }
}

# ------------------------------------------
# 2. APPLICATION & FENÊTRE PRINCIPALE
# ------------------------------------------
$bgColor        = [System.Drawing.ColorTranslator]::FromHtml("#85BBFF")
$headerBgColor = [System.Drawing.ColorTranslator]::FromHtml("#6CA8F7")
$activeTabBg   = [System.Drawing.Color]::White
$inactiveTabBg = [System.Drawing.ColorTranslator]::FromHtml("#A2CDFF")

$form = New-Object System.Windows.Forms.Form
$form.Text = "R2Chap Install - Windows Deployer $ScriptVersion"
$form.Size = New-Object System.Drawing.Size(900, 670)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $False
$form.BackColor = $bgColor
$form.ForeColor = [System.Drawing.Color]::Black

# --- Zone d'en-tête ---
$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Location = New-Object System.Drawing.Point(0, 0)
$headerPanel.Size = New-Object System.Drawing.Size(900, 70)
$headerPanel.BackColor = $headerBgColor
$form.Controls.Add($headerPanel)

$logoPath = if (Test-Path $localLogo) { $localLogo } elseif (Test-Path (Join-Path $assetsDir "Logo.png")) { Join-Path $assetsDir "Logo.png" } else { $null }

if ($logoPath) {
    $pictureBox = New-Object System.Windows.Forms.PictureBox
    $pictureBox.Image = [System.Drawing.Image]::FromFile($logoPath)
    $pictureBox.Location = New-Object System.Drawing.Point(15, 10)
    $pictureBox.Size = New-Object System.Drawing.Size(50, 50)
    $pictureBox.SizeMode = "Zoom"
    $headerPanel.Controls.Add($pictureBox)
}

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "R2CHAP INSTALL"
$lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$lblTitle.ForeColor = [System.Drawing.Color]::Black
$lblTitle.Location = New-Object System.Drawing.Point(75, 12)
$lblTitle.Size = New-Object System.Drawing.Size(250, 25)
$headerPanel.Controls.Add($lblTitle)

$lblSubTitle = New-Object System.Windows.Forms.Label
$lblSubTitle.Text = "Déploiement & Optimisation System - $ScriptVersion"
$lblSubTitle.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
$lblSubTitle.ForeColor = [System.Drawing.Color]::Black
$lblSubTitle.Location = New-Object System.Drawing.Point(75, 38)
$lblSubTitle.Size = New-Object System.Drawing.Size(300, 20)
$headerPanel.Controls.Add($lblSubTitle)

$toolTip = New-Object System.Windows.Forms.ToolTip

# Boutons d'en-tête
$btnUpdateIcon = New-Object System.Windows.Forms.Button
$btnUpdateIcon.Location = New-Object System.Drawing.Point(825, 13)
$btnUpdateIcon.Size = New-Object System.Drawing.Size(44, 44)
$btnUpdateIcon.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnUpdateIcon.FlatAppearance.BorderSize = 0
$btnUpdateIcon.BackColor = [System.Drawing.Color]::Transparent
$btnUpdateIcon.Cursor = [System.Windows.Forms.Cursors]::Hand

$imgUpdate = Get-ResizedImage -filePath $imgUpdatePath -width 32 -height 32
if ($imgUpdate) {
    $btnUpdateIcon.Image = $imgUpdate
    $btnUpdateIcon.ImageAlign = "MiddleCenter"
} else {
    $btnUpdateIcon.Text = "🔄"
    $btnUpdateIcon.Font = New-Object System.Drawing.Font("Segoe UI", 14)
}
$toolTip.SetToolTip($btnUpdateIcon, "Mise à jour du programme R2Chap Install")
$btnUpdateIcon.Add_Click({ Check-AppUpdate })
$headerPanel.Controls.Add($btnUpdateIcon)

$btnSettingsIcon = New-Object System.Windows.Forms.Button
$btnSettingsIcon.Location = New-Object System.Drawing.Point(770, 13)
$btnSettingsIcon.Size = New-Object System.Drawing.Size(44, 44)
$btnSettingsIcon.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnSettingsIcon.FlatAppearance.BorderSize = 0
$btnSettingsIcon.BackColor = [System.Drawing.Color]::Transparent
$btnSettingsIcon.Cursor = [System.Windows.Forms.Cursors]::Hand

$imgSettings = Get-ResizedImage -filePath $imgSettingsPath -width 32 -height 32
if ($imgSettings) {
    $btnSettingsIcon.Image = $imgSettings
    $btnSettingsIcon.ImageAlign = "MiddleCenter"
} else {
    $btnSettingsIcon.Text = "⚙️"
    $btnSettingsIcon.Font = New-Object System.Drawing.Font("Segoe UI", 14)
}
$toolTip.SetToolTip($btnSettingsIcon, "Paramètres de l'application")
$btnSettingsIcon.Add_Click({ Open-SettingsDialog })
$headerPanel.Controls.Add($btnSettingsIcon)

# ------------------------------------------
# 3. GESTIONNAIRE D'ONGLETS
# ------------------------------------------
$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Location = New-Object System.Drawing.Point(10, 80)
$tabControl.Size = New-Object System.Drawing.Size(865, 495)
$tabControl.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
$tabControl.SizeMode = [System.Windows.Forms.TabSizeMode]::Normal
$tabControl.ItemSize = New-Object System.Drawing.Size(135, 30)
$tabControl.DrawMode = [System.Windows.Forms.TabDrawMode]::OwnerDrawFixed
$form.Controls.Add($tabControl)

$tabControl.add_DrawItem({
    param($evtSender, $evtArgs)
    
    $g = $evtArgs.Graphics
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    
    $idx = [int]$evtArgs.Index
    $tabPage = $evtSender.TabPages[$idx]
    $tabBounds = $evtSender.GetTabRect($idx)
    
    $x = [int]$tabBounds.X + 2
    $y = [int]$tabBounds.Y + 2
    $w = [int]$tabBounds.Width - 4
    $h = [int]$tabBounds.Height - 2
    
    $rect = New-Object System.Drawing.Rectangle($x, $y, $w, $h)
    $rectF = New-Object System.Drawing.RectangleF([float]$x, [float]$y, [float]$w, [float]$h)
    
    $isSelected = ($evtSender.SelectedIndex -eq $idx)
    $fillBrush = if ($isSelected) { New-Object System.Drawing.SolidBrush($activeTabBg) } else { New-Object System.Drawing.SolidBrush($inactiveTabBg) }
    $textBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Black)

    $radius = 10
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc([int]$rect.X, [int]$rect.Y, $radius, $radius, 180, 90)
    $path.AddArc([int]($rect.Right - $radius), [int]$rect.Y, $radius, $radius, 270, 90)
    $path.AddLine([int]$rect.Right, [int]$rect.Bottom, [int]$rect.X, [int]$rect.Bottom)
    $path.CloseFigure()
    
    $g.FillPath($fillBrush, $path)
    
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
    $g.DrawString($tabPage.Text.Trim(), $evtSender.Font, $textBrush, $rectF, $sf)
    
    $fillBrush.Dispose()
    $textBrush.Dispose()
    $path.Dispose()
    $sf.Dispose()
})

function Add-CustomTab ($title) {
    $tab = New-Object System.Windows.Forms.TabPage
    $tab.Text = $title
    $tab.BackColor = $bgColor
    $tab.ForeColor = [System.Drawing.Color]::Black
    $tabControl.Controls.Add($tab)
    return $tab
}

# Création des 5 onglets restants
$tabProgramme    = Add-CustomTab "Programme"
$tabDrivers      = Add-CustomTab "Drivers"
$tabCustomR2chap = Add-CustomTab "Custom R2chap"
$tabTweaks       = Add-CustomTab "Tweaks"
$tabMajWindows   = Add-CustomTab "Màj Windows"

# ------------------------------------------
# 4. CHARGEMENT DU CONTENU VIA MODULES
# ------------------------------------------

# Helper d'erreur en cas de module manquant
function Show-ModuleMissingLabel ($targetTab, $moduleName) {
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "⚠ Erreur : Le module $moduleName n'a pas pou être chargé."
    $lbl.ForeColor = [System.Drawing.Color]::Red
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $lbl.Location = New-Object System.Drawing.Point(20, 20)
    $lbl.AutoSize = $true
    $targetTab.Controls.Add($lbl)
}

# 1. Module Software
if (Get-Command "Build-TabProgramme" -ErrorAction SilentlyContinue) {
    Build-TabProgramme -TargetTab $tabProgramme -ParentForm $form -BgColor $bgColor
} else {
    Show-ModuleMissingLabel -targetTab $tabProgramme -moduleName "Software.ps1"
}

# 2. Module Drivers
if (Get-Command "Build-TabDrivers" -ErrorAction SilentlyContinue) {
    Build-TabDrivers -TargetTab $tabDrivers -ParentForm $form -BgColor $bgColor
} else {
    Show-ModuleMissingLabel -targetTab $tabDrivers -moduleName "Drivers.ps1"
}

# 3. Module Customization (Custom R2chap)
if (Get-Command "Build-TabCustomR2chap" -ErrorAction SilentlyContinue) {
    Build-TabCustomR2chap -TargetTab $tabCustomR2chap -ParentForm $form -BgColor $bgColor
} elseif (Get-Command "Build-TabCustomization" -ErrorAction SilentlyContinue) {
    Build-TabCustomization -TargetTab $tabCustomR2chap -ParentForm $form -BgColor $bgColor
} else {
    Show-ModuleMissingLabel -targetTab $tabCustomR2chap -moduleName "Customization.ps1"
}

# 4. Module System Tweaks
if (Get-Command "Build-TabTweaks" -ErrorAction SilentlyContinue) {
    Build-TabTweaks -TargetTab $tabTweaks -ParentForm $form -BgColor $bgColor
} elseif (Get-Command "Build-TabSystemTweaks" -ErrorAction SilentlyContinue) {
    Build-TabSystemTweaks -TargetTab $tabTweaks -ParentForm $form -BgColor $bgColor
} else {
    Show-ModuleMissingLabel -targetTab $tabTweaks -moduleName "SystemTweaks.ps1"
}

# 5. Module Windows Update
if (Get-Command "Build-TabMajWindows" -ErrorAction SilentlyContinue) {
    Build-TabMajWindows -TargetTab $tabMajWindows -ParentForm $form -BgColor $bgColor
} elseif (Get-Command "Build-TabWindowsUpdate" -ErrorAction SilentlyContinue) {
    Build-TabWindowsUpdate -TargetTab $tabMajWindows -ParentForm $form -BgColor $bgColor
} else {
    Show-ModuleMissingLabel -targetTab $tabMajWindows -moduleName "WindowsUpdate.ps1"
}

# ------------------------------------------
# 5. BOUTONS BAS DE FENÊTRE
# ------------------------------------------
$btnQuitter = New-Object System.Windows.Forms.Button
$btnQuitter.Text = "Quitter"
$btnQuitter.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
$btnQuitter.Size = New-Object System.Drawing.Size(100, 35)
$btnQuitter.Location = New-Object System.Drawing.Point(775, 585)
$btnQuitter.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnQuitter.FlatAppearance.BorderSize = 0
$btnQuitter.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#FF0000")
$btnQuitter.ForeColor = [System.Drawing.Color]::White
$btnQuitter.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnQuitter.Add_Click({ $form.Close() })
$form.Controls.Add($btnQuitter)

$btnTotalConversion = New-Object System.Windows.Forms.Button
$btnTotalConversion.Text = "Total conversion"
$btnTotalConversion.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
$btnTotalConversion.Size = New-Object System.Drawing.Size(140, 35)
$btnTotalConversion.Location = New-Object System.Drawing.Point(625, 585)
$btnTotalConversion.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnTotalConversion.FlatAppearance.BorderSize = 0
$btnTotalConversion.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#B007B5")
$btnTotalConversion.ForeColor = [System.Drawing.Color]::White
$btnTotalConversion.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnTotalConversion.Add_Click({ Start-TotalConversion })
$form.Controls.Add($btnTotalConversion)

$form.ShowDialog() | Out-Null