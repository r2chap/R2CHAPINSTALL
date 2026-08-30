# ==========================================
# MODULE : BACKUP & TRANSFER (Sauvegarde & Transfert)
# Fichier : modules/BackupTransfer.ps1
# Version : v1.9
# ==========================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ------------------------------------------
# CONSTRUCTION DE L'ONGLET SAUVEGARDE & TRANSFERT
# ------------------------------------------
function Build-TabBackupTransfer {
    param(
        [System.Windows.Forms.TabPage]$TargetTab,
        [System.Windows.Forms.Form]$ParentForm,
        [System.Drawing.Color]$BgColor
    )

    $TargetTab.BackColor = $BgColor

    $fontSection = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $fontItem    = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
    $fontBtn     = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)

    # ==========================================
    # PANNEAU GAUCHE : SAUVEGARDE (EXPORT)
    # ==========================================
    $panelLeft = New-Object System.Windows.Forms.GroupBox
    $panelLeft.Text = " SAUVEGARDE (PC Source) "
    $panelLeft.Font = $fontSection
    $panelLeft.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#58A6FF")
    $panelLeft.Location = New-Object System.Drawing.Point(15, 15)
    $panelLeft.Size = New-Object System.Drawing.Size(410, 310)
    $TargetTab.Controls.Add($panelLeft)

    # Destination
    $lblBackupDest = New-Object System.Windows.Forms.Label
    $lblBackupDest.Text = "Emplacement de sauvegarde :"
    $lblBackupDest.Font = $fontItem
    $lblBackupDest.ForeColor = [System.Drawing.Color]::White
    $lblBackupDest.Location = New-Object System.Drawing.Point(15, 23)
    $lblBackupDest.Size = New-Object System.Drawing.Size(200, 18)
    $panelLeft.Controls.Add($lblBackupDest)

    $script:txtBackupDest = New-Object System.Windows.Forms.TextBox
    $script:txtBackupDest.Location = New-Object System.Drawing.Point(15, 43)
    $script:txtBackupDest.Size = New-Object System.Drawing.Size(280, 23)
    $script:txtBackupDest.Font = $fontItem
    $script:txtBackupDest.ReadOnly = $true
    $script:txtBackupDest.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#0D1117")
    $script:txtBackupDest.ForeColor = [System.Drawing.Color]::White
    $panelLeft.Controls.Add($script:txtBackupDest)

    $btnBrowseBackup = New-Object System.Windows.Forms.Button
    $btnBrowseBackup.Text = "Parcourir..."
    $btnBrowseBackup.Font = $fontBtn
    $btnBrowseBackup.Location = New-Object System.Drawing.Point(300, 42)
    $btnBrowseBackup.Size = New-Object System.Drawing.Size(95, 25)
    $btnBrowseBackup.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#1F6FEB")
    $btnBrowseBackup.ForeColor = [System.Drawing.Color]::White
    $btnBrowseBackup.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnBrowseBackup.FlatAppearance.BorderSize = 0
    $btnBrowseBackup.Cursor = [System.Windows.Forms.Cursors]::Hand
    $panelLeft.Controls.Add($btnBrowseBackup)

    # Option Dossier Utilisateur Complet
    $script:chkFullUser = New-Object System.Windows.Forms.CheckBox
    $script:chkFullUser.Text = "[*] Profil Utilisateur complet ($env:USERNAME)"
    $script:chkFullUser.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $script:chkFullUser.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#58A6FF")
    $script:chkFullUser.Location = New-Object System.Drawing.Point(15, 75)
    $script:chkFullUser.Size = New-Object System.Drawing.Size(350, 22)
    $panelLeft.Controls.Add($script:chkFullUser)

    # Éléments individuels (Sauvegarde)
    $lblSelectBackup = New-Object System.Windows.Forms.Label
    $lblSelectBackup.Text = "Ou sélectionner des dossiers spécifiques :"
    $lblSelectBackup.Font = $fontItem
    $lblSelectBackup.ForeColor = [System.Drawing.Color]::Gray
    $lblSelectBackup.Location = New-Object System.Drawing.Point(15, 100)
    $lblSelectBackup.Size = New-Object System.Drawing.Size(250, 18)
    $panelLeft.Controls.Add($lblSelectBackup)

    $script:chkDesktop   = New-Object System.Windows.Forms.CheckBox; $script:chkDesktop.Text = "Bureau"; $script:chkDesktop.Checked = $true; $script:chkDesktop.ForeColor = [System.Drawing.Color]::White; $script:chkDesktop.Location = New-Object System.Drawing.Point(20, 122); $script:chkDesktop.Size = New-Object System.Drawing.Size(170, 20); $script:chkDesktop.Font = $fontItem; $panelLeft.Controls.Add($script:chkDesktop)
    $script:chkDocuments = New-Object System.Windows.Forms.CheckBox; $script:chkDocuments.Text = "Documents"; $script:chkDocuments.Checked = $true; $script:chkDocuments.ForeColor = [System.Drawing.Color]::White; $script:chkDocuments.Location = New-Object System.Drawing.Point(200, 122); $script:chkDocuments.Size = New-Object System.Drawing.Size(170, 20); $script:chkDocuments.Font = $fontItem; $panelLeft.Controls.Add($script:chkDocuments)
    $script:chkDownloads = New-Object System.Windows.Forms.CheckBox; $script:chkDownloads.Text = "Téléchargements"; $script:chkDownloads.Checked = $true; $script:chkDownloads.ForeColor = [System.Drawing.Color]::White; $script:chkDownloads.Location = New-Object System.Drawing.Point(20, 145); $script:chkDownloads.Size = New-Object System.Drawing.Size(170, 20); $script:chkDownloads.Font = $fontItem; $panelLeft.Controls.Add($script:chkDownloads)
    $script:chkPictures  = New-Object System.Windows.Forms.CheckBox; $script:chkPictures.Text = "Images"; $script:chkPictures.Checked = $true; $script:chkPictures.ForeColor = [System.Drawing.Color]::White; $script:chkPictures.Location = New-Object System.Drawing.Point(200, 145); $script:chkPictures.Size = New-Object System.Drawing.Size(170, 20); $script:chkPictures.Font = $fontItem; $panelLeft.Controls.Add($script:chkPictures)
    $script:chkVideos    = New-Object System.Windows.Forms.CheckBox; $script:chkVideos.Text = "Vidéos"; $script:chkVideos.Checked = $true; $script:chkVideos.ForeColor = [System.Drawing.Color]::White; $script:chkVideos.Location = New-Object System.Drawing.Point(20, 168); $script:chkVideos.Size = New-Object System.Drawing.Size(170, 20); $script:chkVideos.Font = $fontItem; $panelLeft.Controls.Add($script:chkVideos)
    $script:chkMusic     = New-Object System.Windows.Forms.CheckBox; $script:chkMusic.Text = "Musique"; $script:chkMusic.Checked = $true; $script:chkMusic.ForeColor = [System.Drawing.Color]::White; $script:chkMusic.Location = New-Object System.Drawing.Point(200, 168); $script:chkMusic.Size = New-Object System.Drawing.Size(170, 20); $script:chkMusic.Font = $fontItem; $panelLeft.Controls.Add($script:chkMusic)
    $script:chkFavorites = New-Object System.Windows.Forms.CheckBox; $script:chkFavorites.Text = "Favoris"; $script:chkFavorites.Checked = $true; $script:chkFavorites.ForeColor = [System.Drawing.Color]::White; $script:chkFavorites.Location = New-Object System.Drawing.Point(20, 191); $script:chkFavorites.Size = New-Object System.Drawing.Size(170, 20); $script:chkFavorites.Font = $fontItem; $panelLeft.Controls.Add($script:chkFavorites)

    $chkListBackup = @($script:chkDesktop, $script:chkDocuments, $script:chkDownloads, $script:chkPictures, $script:chkVideos, $script:chkMusic, $script:chkFavorites)

    $script:chkFullUser.Add_CheckedChanged({
        $enabled = -not $script:chkFullUser.Checked
        foreach ($item in $chkListBackup) { $item.Enabled = $enabled }
    })

    # Bouton Lancer Sauvegarde
    $btnStartBackup = New-Object System.Windows.Forms.Button
    $btnStartBackup.Text = "💾 Lancer la Sauvegarde"
    $btnStartBackup.Font = $fontBtn
    $btnStartBackup.Size = New-Object System.Drawing.Size(380, 40)
    $btnStartBackup.Location = New-Object System.Drawing.Point(15, 250)
    $btnStartBackup.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#1F6FEB")
    $btnStartBackup.ForeColor = [System.Drawing.Color]::White
    $btnStartBackup.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnStartBackup.FlatAppearance.BorderSize = 0
    $btnStartBackup.Cursor = [System.Windows.Forms.Cursors]::Hand
    $panelLeft.Controls.Add($btnStartBackup)


    # ==========================================
    # PANNEAU DROIT : RESTAURATION / TRANSFERT (IMPORT)
    # ==========================================
    $panelRight = New-Object System.Windows.Forms.GroupBox
    $panelRight.Text = " RESTAURATION / TRANSFERT (PC Cible) "
    $panelRight.Font = $fontSection
    $panelRight.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#7EE787")
    $panelRight.Location = New-Object System.Drawing.Point(435, 15)
    $panelRight.Size = New-Object System.Drawing.Size(410, 310)
    $TargetTab.Controls.Add($panelRight)

    # Source
    $lblRestoreSource = New-Object System.Windows.Forms.Label
    $lblRestoreSource.Text = "Dossier source de sauvegarde :"
    $lblRestoreSource.Font = $fontItem
    $lblRestoreSource.ForeColor = [System.Drawing.Color]::White
    $lblRestoreSource.Location = New-Object System.Drawing.Point(15, 23)
    $lblRestoreSource.Size = New-Object System.Drawing.Size(220, 18)
    $panelRight.Controls.Add($lblRestoreSource)

    $script:txtRestoreSource = New-Object System.Windows.Forms.TextBox
    $script:txtRestoreSource.Location = New-Object System.Drawing.Point(15, 43)
    $script:txtRestoreSource.Size = New-Object System.Drawing.Size(280, 23)
    $script:txtRestoreSource.Font = $fontItem
    $script:txtRestoreSource.ReadOnly = $true
    $script:txtRestoreSource.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#0D1117")
    $script:txtRestoreSource.ForeColor = [System.Drawing.Color]::White
    $panelRight.Controls.Add($script:txtRestoreSource)

    $btnBrowseRestore = New-Object System.Windows.Forms.Button
    $btnBrowseRestore.Text = "Parcourir..."
    $btnBrowseRestore.Font = $fontBtn
    $btnBrowseRestore.Location = New-Object System.Drawing.Point(300, 42)
    $btnBrowseRestore.Size = New-Object System.Drawing.Size(95, 25)
    $btnBrowseRestore.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#238636")
    $btnBrowseRestore.ForeColor = [System.Drawing.Color]::White
    $btnBrowseRestore.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnBrowseRestore.FlatAppearance.BorderSize = 0
    $btnBrowseRestore.Cursor = [System.Windows.Forms.Cursors]::Hand
    $panelRight.Controls.Add($btnBrowseRestore)

    # Option Restauration Profil complet
    $script:chkRestFullUser = New-Object System.Windows.Forms.CheckBox
    $script:chkRestFullUser.Text = "[*] Restaurer l'intégralité du profil User"
    $script:chkRestFullUser.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $script:chkRestFullUser.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#7EE787")
    $script:chkRestFullUser.Location = New-Object System.Drawing.Point(15, 75)
    $script:chkRestFullUser.Size = New-Object System.Drawing.Size(350, 22)
    $panelRight.Controls.Add($script:chkRestFullUser)

    $lblSelectRestore = New-Object System.Windows.Forms.Label
    $lblSelectRestore.Text = "Ou restaurer des dossiers spécifiques :"
    $lblSelectRestore.Font = $fontItem
    $lblSelectRestore.ForeColor = [System.Drawing.Color]::Gray
    $lblSelectRestore.Location = New-Object System.Drawing.Point(15, 100)
    $lblSelectRestore.Size = New-Object System.Drawing.Size(250, 18)
    $panelRight.Controls.Add($lblSelectRestore)

    $script:chkRestDesktop   = New-Object System.Windows.Forms.CheckBox; $script:chkRestDesktop.Text = "Bureau"; $script:chkRestDesktop.Checked = $true; $script:chkRestDesktop.ForeColor = [System.Drawing.Color]::White; $script:chkRestDesktop.Location = New-Object System.Drawing.Point(20, 122); $script:chkRestDesktop.Size = New-Object System.Drawing.Size(170, 20); $script:chkRestDesktop.Font = $fontItem; $panelRight.Controls.Add($script:chkRestDesktop)
    $script:chkRestDocuments = New-Object System.Windows.Forms.CheckBox; $script:chkRestDocuments.Text = "Documents"; $script:chkRestDocuments.Checked = $true; $script:chkRestDocuments.ForeColor = [System.Drawing.Color]::White; $script:chkRestDocuments.Location = New-Object System.Drawing.Point(200, 122); $script:chkRestDocuments.Size = New-Object System.Drawing.Size(170, 20); $script:chkRestDocuments.Font = $fontItem; $panelRight.Controls.Add($script:chkRestDocuments)
    $script:chkRestDownloads = New-Object System.Windows.Forms.CheckBox; $script:chkRestDownloads.Text = "Téléchargements"; $script:chkRestDownloads.Checked = $true; $script:chkRestDownloads.ForeColor = [System.Drawing.Color]::White; $script:chkRestDownloads.Location = New-Object System.Drawing.Point(20, 145); $script:chkRestDownloads.Size = New-Object System.Drawing.Size(170, 20); $script:chkRestDownloads.Font = $fontItem; $panelRight.Controls.Add($script:chkRestDownloads)
    $script:chkRestPictures  = New-Object System.Windows.Forms.CheckBox; $script:chkRestPictures.Text = "Images"; $script:chkRestPictures.Checked = $true; $script:chkRestPictures.ForeColor = [System.Drawing.Color]::White; $script:chkRestPictures.Location = New-Object System.Drawing.Point(200, 145); $script:chkRestPictures.Size = New-Object System.Drawing.Size(170, 20); $script:chkRestPictures.Font = $fontItem; $panelRight.Controls.Add($script:chkRestPictures)
    $script:chkRestVideos    = New-Object System.Windows.Forms.CheckBox; $script:chkRestVideos.Text = "Vidéos"; $script:chkRestVideos.Checked = $true; $script:chkRestVideos.ForeColor = [System.Drawing.Color]::White; $script:chkRestVideos.Location = New-Object System.Drawing.Point(20, 168); $script:chkRestVideos.Size = New-Object System.Drawing.Size(170, 20); $script:chkRestVideos.Font = $fontItem; $panelRight.Controls.Add($script:chkRestVideos)
    $script:chkRestMusic     = New-Object System.Windows.Forms.CheckBox; $script:chkRestMusic.Text = "Musique"; $script:chkRestMusic.Checked = $true; $script:chkRestMusic.ForeColor = [System.Drawing.Color]::White; $script:chkRestMusic.Location = New-Object System.Drawing.Point(200, 168); $script:chkRestMusic.Size = New-Object System.Drawing.Size(170, 20); $script:chkRestMusic.Font = $fontItem; $panelRight.Controls.Add($script:chkRestMusic)
    $script:chkRestFavorites = New-Object System.Windows.Forms.CheckBox; $script:chkRestFavorites.Text = "Favoris"; $script:chkRestFavorites.Checked = $true; $script:chkRestFavorites.ForeColor = [System.Drawing.Color]::White; $script:chkRestFavorites.Location = New-Object System.Drawing.Point(20, 191); $script:chkRestFavorites.Size = New-Object System.Drawing.Size(170, 20); $script:chkRestFavorites.Font = $fontItem; $panelRight.Controls.Add($script:chkRestFavorites)

    $chkListRestore = @($script:chkRestDesktop, $script:chkRestDocuments, $script:chkRestDownloads, $script:chkRestPictures, $script:chkRestVideos, $script:chkRestMusic, $script:chkRestFavorites)

    $script:chkRestFullUser.Add_CheckedChanged({
        $enabled = -not $script:chkRestFullUser.Checked
        foreach ($item in $chkListRestore) { $item.Enabled = $enabled }
    })

    # Bouton Lancer Restauration
    $btnStartRestore = New-Object System.Windows.Forms.Button
    $btnStartRestore.Text = "📂 Lancer la Restauration / Transfert"
    $btnStartRestore.Font = $fontBtn
    $btnStartRestore.Size = New-Object System.Drawing.Size(380, 40)
    $btnStartRestore.Location = New-Object System.Drawing.Point(15, 250)
    $btnStartRestore.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#238636")
    $btnStartRestore.ForeColor = [System.Drawing.Color]::White
    $btnStartRestore.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnStartRestore.FlatAppearance.BorderSize = 0
    $btnStartRestore.Cursor = [System.Windows.Forms.Cursors]::Hand
    $panelRight.Controls.Add($btnStartRestore)


    # ==========================================
    # ACTIONS DES BOUTONS
    # ==========================================
    $btnBrowseBackup.Add_Click({
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $dialog.Description = "Sélectionnez le dossier ou disque externe de destination"
        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $script:txtBackupDest.Text = $dialog.SelectedPath
        }
    })

    $btnBrowseRestore.Add_Click({
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $dialog.Description = "Sélectionnez le dossier contenant les données sauvegardées"
        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $script:txtRestoreSource.Text = $dialog.SelectedPath
        }
    })

    # Action Sauvegarde
    $btnStartBackup.Add_Click({
        if ([string]::IsNullOrWhiteSpace($script:txtBackupDest.Text)) {
            [System.Windows.Forms.MessageBox]::Show("Veuillez choisir un emplacement de destination.", "Attention", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }

        $userProfile = $env:USERPROFILE
        $targetRoot  = Join-Path $script:txtBackupDest.Text "Sauvegarde_$env:USERNAME_$([DateTime]::Now.ToString('yyyy-MM-dd_HHmm'))"

        Write-Log -Message "DÉBUT DE LA SAUVEGARDE CLIENT..." -Color ([System.Drawing.Color]::Cyan)

        if ($script:chkFullUser.Checked) {
            Write-Log -Message "Copie de l'intégralité du profil utilisateur : $userProfile" -Color ([System.Drawing.Color]::White)
            if ($ParentForm) { $ParentForm.Refresh() }

            $destPath = Join-Path $targetRoot "UserProfile_Complet"
            
            robocopy $userProfile $destPath /E /R:1 /W:1 /XD "AppData\Local\Temp" "AppData\Local\Microsoft\Windows\INetCache" /NDL /NFL /NJH /NJS | Out-Null
            
            Write-Log -Message "-> Profil utilisateur complet sauvegardé." -Color ([System.Drawing.Color]::ForestGreen)
        } else {
            $itemsToCopy = @()
            if ($script:chkDesktop.Checked)   { $itemsToCopy += @{ Name="Desktop";   Source=(Join-Path $userProfile "Desktop") } }
            if ($script:chkDocuments.Checked) { $itemsToCopy += @{ Name="Documents"; Source=(Join-Path $userProfile "Documents") } }
            if ($script:chkDownloads.Checked) { $itemsToCopy += @{ Name="Downloads"; Source=(Join-Path $userProfile "Downloads") } }
            if ($script:chkPictures.Checked)  { $itemsToCopy += @{ Name="Pictures";  Source=(Join-Path $userProfile "Pictures") } }
            if ($script:chkVideos.Checked)    { $itemsToCopy += @{ Name="Videos";    Source=(Join-Path $userProfile "Videos") } }
            if ($script:chkMusic.Checked)     { $itemsToCopy += @{ Name="Music";     Source=(Join-Path $userProfile "Music") } }
            if ($script:chkFavorites.Checked) { $itemsToCopy += @{ Name="Favorites"; Source=(Join-Path $userProfile "Favorites") } }

            if ($itemsToCopy.Count -eq 0) {
                [System.Windows.Forms.MessageBox]::Show("Aucun dossier sélectionné.", "Attention", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
                return
            }

            foreach ($item in $itemsToCopy) {
                $destPath = Join-Path $targetRoot $item.Name

                if (Test-Path $item.Source) {
                    Write-Log -Message "Copie de $($item.Name) en cours..." -Color ([System.Drawing.Color]::Yellow)
                    if ($ParentForm) { $ParentForm.Refresh() }

                    robocopy $item.Source $destPath /E /R:1 /W:1 /NDL /NFL /NJH /NJS | Out-Null

                    Write-Log -Message "-> $($item.Name) copié." -Color ([System.Drawing.Color]::ForestGreen)
                } else {
                    Write-Log -Message "! Dossier introuvable : $($item.Source)" -Color ([System.Drawing.Color]::Orange)
                }

                if ($ParentForm) { $ParentForm.Refresh() }
            }
        }

        Write-Log -Message "SUCCÈS : Sauvegarde terminée dans $targetRoot" -Color ([System.Drawing.Color]::ForestGreen)
        [System.Windows.Forms.MessageBox]::Show("La sauvegarde s'est terminée avec succès !", "Terminé", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    })

    # Action Restauration
    $btnStartRestore.Add_Click({
        if ([string]::IsNullOrWhiteSpace($script:txtRestoreSource.Text)) {
            [System.Windows.Forms.MessageBox]::Show("Veuillez choisir le dossier source de la sauvegarde.", "Attention", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }

        $userProfile = $env:USERPROFILE
        $sourceRoot  = $script:txtRestoreSource.Text

        Write-Log -Message "DÉBUT DU TRANSFERT / RESTAURATION..." -Color ([System.Drawing.Color]::Cyan)

        if ($script:chkRestFullUser.Checked) {
            $fullSource = Join-Path $sourceRoot "UserProfile_Complet"
            if (-not (Test-Path $fullSource)) { $fullSource = $sourceRoot }

            Write-Log -Message "Restauration complète du profil vers : $userProfile" -Color ([System.Drawing.Color]::White)
            if ($ParentForm) { $ParentForm.Refresh() }

            robocopy $fullSource $userProfile /E /R:1 /W:1 /XD "AppData\Local\Temp" /NDL /NFL /NJH /NJS | Out-Null

            Write-Log -Message "-> Intégralité du profil restauré avec succès." -Color ([System.Drawing.Color]::ForestGreen)
        } else {
            $itemsToRestore = @()
            if ($script:chkRestDesktop.Checked)   { $itemsToRestore += @{ Name="Desktop";   Dest=(Join-Path $userProfile "Desktop") } }
            if ($script:chkRestDocuments.Checked) { $itemsToRestore += @{ Name="Documents"; Dest=(Join-Path $userProfile "Documents") } }
            if ($script:chkRestDownloads.Checked) { $itemsToRestore += @{ Name="Downloads"; Dest=(Join-Path $userProfile "Downloads") } }
            if ($script:chkRestPictures.Checked)  { $itemsToRestore += @{ Name="Pictures";  Dest=(Join-Path $userProfile "Pictures") } }
            if ($script:chkRestVideos.Checked)    { $itemsToRestore += @{ Name="Videos";    Dest=(Join-Path $userProfile "Videos") } }
            if ($script:chkRestMusic.Checked)     { $itemsToRestore += @{ Name="Music";     Dest=(Join-Path $userProfile "Music") } }
            if ($script:chkRestFavorites.Checked) { $itemsToRestore += @{ Name="Favorites"; Dest=(Join-Path $userProfile "Favorites") } }

            if ($itemsToRestore.Count -eq 0) {
                [System.Windows.Forms.MessageBox]::Show("Aucun élément sélectionné pour la restauration.", "Attention", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
                return
            }

            foreach ($item in $itemsToRestore) {
                $sourcePath = Join-Path $sourceRoot $item.Name

                if (Test-Path $sourcePath) {
                    Write-Log -Message "Restauration de $($item.Name)..." -Color ([System.Drawing.Color]::Yellow)
                    if ($ParentForm) { $ParentForm.Refresh() }

                    robocopy $sourcePath $item.Dest /E /R:1 /W:1 /NDL /NFL /NJH /NJS | Out-Null

                    Write-Log -Message "-> $($item.Name) restauré." -Color ([System.Drawing.Color]::ForestGreen)
                } else {
                    Write-Log -Message "! Sauvegarde introuvable pour $($item.Name)" -Color ([System.Drawing.Color]::Orange)
                }

                if ($ParentForm) { $ParentForm.Refresh() }
            }
        }

        Write-Log -Message "SUCCÈS : Transfert et restauration terminés !" -Color ([System.Drawing.Color]::ForestGreen)
        [System.Windows.Forms.MessageBox]::Show("Les données ont été restaurées avec succès !", "Terminé", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    })
}