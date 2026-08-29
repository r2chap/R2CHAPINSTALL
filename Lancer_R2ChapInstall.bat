@echo off
:: Force la console Windows en UTF-8 pour supporter correctement les accents
chcp 65001 >nul

:: Vérification et demande des privilèges Administrateur
net session >nul 2>&1
if %errorLevel% neq 0 (
    powershell -Command "Start-Process '%~0' -Verb RunAs"
    exit /b
)

:: Se positionner dans le répertoire du script
cd /d "%~dp0"

:: Exécution du script PowerShell avec encodage UTF-8
powershell -ExecutionPolicy Bypass -NoProfile -Command "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; & '%~dp0R2ChapInstall.ps1'"