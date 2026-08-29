# ==========================================
# MODULE : WINDOWS UPDATE (Mises à jour Windows)
# Fichier : modules/WindowsUpdate.ps1
# ==========================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ------------------------------------------
# HELPER : LOGGING
# ------------------------------------------
function Write-UpdateLog {
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
# FONCTION 1 : OUVRIR L'INTERFACE WINDOWS UPDATE
# ------------------------------------------
function Open-WindowsUpdateGUI {
    try {
        Start-Process "ms-settings:windowsupdate"
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Impossible d'ouvrir la page des Paramètres Windows Update.", "Erreur", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

# ------------------------------------------
# FONCTION 2 : RECHERCHE ET INSTALLATION DES MAJ VIA COM (WUApiLib)
# ------------------------------------------
function Start-WindowsUpdateProcess {
    param(
        [System.Windows.Forms.RichTextBox]$LogBox,
        [System.Windows.Forms.ProgressBar]$ProgressBar,
        [System.Windows.Forms.Form]$ParentForm
    )

    Write-UpdateLog -LogBox $LogBox -Message "==========================================" -Color ([System.Drawing.Color]::Blue)
    Write-UpdateLog -LogBox $LogBox -Message "ACTION : Recherche des mises à jour Windows disponibles..." -Color ([System.Drawing.Color]::Blue)
    
    if ($ProgressBar) { $ProgressBar.Value = 10 }
    if ($ParentForm) { $ParentForm.Refresh() }

    try {
        # Initialisation de l'API COM Windows Update
        $updateSession = New-Object -ComObject Microsoft.Update.Session
        $updateSearcher = $updateSession.CreateUpdateSearcher()

        # Recherche des MAJ non installées
        $searchResult = $updateSearcher.Search("IsInstalled=0 and Type='Software'")
        $updatesToDownload = New-Object -ComObject Microsoft.Update.UpdateColl

        if ($searchResult.Updates.Count -eq 0) {
            if ($ProgressBar) { $ProgressBar.Value = 100 }
            Write-UpdateLog -LogBox $LogBox -Message "SUCCÈS : Votre système est déjà à jour. Aucune mise à jour disponible." -Color ([System.Drawing.Color]::ForestGreen)
            [System.Windows.Forms.MessageBox]::Show("Votre système est entièrement à jour !`nAucune mise à jour n'est disponible pour le moment.", "Windows Update", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            return
        }

        # Construction de la liste des MAJ trouvées
        $updateListText = ""
        $count = 1
        foreach ($update in $searchResult.Updates) {
            $updateListText += "$count. $($update.Title)`n"
            $updatesToDownload.Add($update) | Out-Null
            $count++
        }

        # BOÎTE DE DIALOGUE : Affichage des MAJ disponibles et confirmation
        $msgPrompt = "Mises à jour disponibles trouvées ($($searchResult.Updates.Count)) :`n`n" + $updateListText + "`nVoulez-vous lancer le téléchargement et l'installation dès maintenant ?"
        $dialogResult = [System.Windows.Forms.MessageBox]::Show($msgPrompt, "Mises à jour disponibles", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)

        if ($dialogResult -ne [System.Windows.Forms.DialogResult]::Yes) {
            Write-UpdateLog -LogBox $LogBox -Message "ANNULATION : Installation annulée par l'utilisateur." -Color ([System.Drawing.Color]::Orange)
            if ($ProgressBar) { $ProgressBar.Value = 0 }
            return
        }

        # ----------------------------------
        # ETAPE 1 : TÉLÉCHARGEMENT
        # ----------------------------------
        Write-UpdateLog -LogBox $LogBox -Message "Téléchargement des $( $updatesToDownload.Count ) mises à jour en cours..." -Color ([System.Drawing.Color]::DarkSlateGray)
        if ($ProgressBar) { $ProgressBar.Value = 30 }
        if ($ParentForm) { $ParentForm.Refresh() }

        $downloader = $updateSession.CreateUpdateDownloader()
        $downloader.Updates = $updatesToDownload
        $downloader.Download()

        Write-UpdateLog -LogBox $LogBox -Message "SUCCÈS : Téléchargement terminé avec succès." -Color ([System.Drawing.Color]::ForestGreen)

        # ----------------------------------
        # ETAPE 2 : INSTALLATION
        # ----------------------------------
        Write-UpdateLog -LogBox $LogBox -Message "Installation des mises à jour en cours (cela peut prendre plusieurs minutes)..." -Color ([System.Drawing.Color]::DarkSlateGray)
        if ($ProgressBar) { $ProgressBar.Value = 60 }
        if ($ParentForm) { $ParentForm.Refresh() }

        $updatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl
        foreach ($update in $searchResult.Updates) {
            if ($update.IsDownloaded) {
                $updatesToInstall.Add($update) | Out-Null
            }
        }

        $installer = $updateSession.CreateUpdateInstaller()
        $installer.Updates = $updatesToInstall
        $installResult = $installer.Install()

        if ($ProgressBar) { $ProgressBar.Value = 100 }

        # Vérification si un redémarrage est requis
        $rebootRequired = $installResult.RebootRequired

        Write-UpdateLog -LogBox $LogBox -Message "SUCCÈS : Installation des mises à jour terminée !" -Color ([System.Drawing.Color]::ForestGreen)

        if ($rebootRequired) {
            Write-UpdateLog -LogBox $LogBox -Message "ATTENTION : Un redémarrage du PC est nécessaire pour finaliser l'installation." -Color ([System.Drawing.Color]::Orange)
            [System.Windows.Forms.MessageBox]::Show("Toutes les mises à jour ont été installées avec succès !`n`nUn redémarrage de votre PC est requis pour finaliser l'installation.", "Mise à jour terminée", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        } else {
            [System.Windows.Forms.MessageBox]::Show("Toutes les mises à jour ont été installées avec succès !", "Mise à jour terminée", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        }

    } catch {
        $errorMsg = $_.Exception.Message
        Write-UpdateLog -LogBox $LogBox -Message "ERREUR : Impossible de traiter les mises à jour : $errorMsg" -Color ([System.Drawing.Color]::Red)
        [System.Windows.Forms.MessageBox]::Show("Une erreur est survenue lors du processus Windows Update.`n`nDétails : $errorMsg", "Erreur Windows Update", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

# ------------------------------------------
# CONSTRUCTION DE L'ONGLET WINDOWS UPDATE
# ------------------------------------------
function Build-TabWindowsUpdate {
    param(
        [System.Windows.Forms.TabPage]$TargetTab,
        [System.Windows.Forms.Form]$ParentForm,
        [System.Drawing.Color]$BgColor
    )

    $TargetTab.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#12181F")

    $fontTitle = New-Object System.Drawing.Font("Consolas", 12, [System.Drawing.FontStyle]::Bold)
    $fontBtn   = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)

    # Titre de la section
    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = "Gestion des Mises à Jour Windows (Windows Update)"
    $lblTitle.Font = $fontTitle
    $lblTitle.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#58A6FF")
    $lblTitle.Size = New-Object System.Drawing.Size(800, 25)
    $lblTitle.Location = New-Object System.Drawing.Point(15, 15)
    $TargetTab.Controls.Add($lblTitle)

    # BOUTON 1 : Ouvrir les Paramètres Windows Update
    $btnOpenGUI = New-Object System.Windows.Forms.Button
    $btnOpenGUI.Text = "Ouvrir Windows Update (Paramètres Windows)"
    $btnOpenGUI.Font = $fontBtn
    $btnOpenGUI.Size = New-Object System.Drawing.Size(320, 40)
    $btnOpenGUI.Location = New-Object System.Drawing.Point(15, 55)
    $btnOpenGUI.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#21262D")
    $btnOpenGUI.ForeColor = [System.Drawing.Color]::White
    $btnOpenGUI.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnOpenGUI.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnOpenGUI.Add_Click({
        Open-WindowsUpdateGUI
    })
    $TargetTab.Controls.Add($btnOpenGUI)

    # BOUTON 2 : Lancer les mises à jour directement
    $btnStartUpdate = New-Object System.Windows.Forms.Button
    $btnStartUpdate.Text = "Rechercher & Installer les Mises à Jour"
    $btnStartUpdate.Font = $fontBtn
    $btnStartUpdate.Size = New-Object System.Drawing.Size(320, 40)
    $btnStartUpdate.Location = New-Object System.Drawing.Point(350, 55)
    $btnStartUpdate.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#1F6FEB")
    $btnStartUpdate.ForeColor = [System.Drawing.Color]::White
    $btnStartUpdate.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnStartUpdate.Cursor = [System.Windows.Forms.Cursors]::Hand
    $TargetTab.Controls.Add($btnStartUpdate)

    # Console Log de suivi
    $logBox = New-Object System.Windows.Forms.RichTextBox
    $logBox.Location = New-Object System.Drawing.Point(15, 110)
    $logBox.Size = New-Object System.Drawing.Size(830, 310)
    $logBox.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#0D1117")
    $logBox.ForeColor = [System.Drawing.Color]::White
    $logBox.ReadOnly = $true
    $logBox.Font = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Regular)
    $TargetTab.Controls.Add($logBox)

    # Barre de progression
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(15, 430)
    $progressBar.Size = New-Object System.Drawing.Size(830, 20)
    $progressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Continuous
    $TargetTab.Controls.Add($progressBar)

    # Association de l'événement clic pour le bouton de recherche/installation
    $lBox = $logBox
    $pBar = $progressBar
    $pForm = $ParentForm

    $btnStartUpdate.Add_Click({
        Start-WindowsUpdateProcess -LogBox $lBox -ProgressBar $pBar -ParentForm $pForm
    })
}