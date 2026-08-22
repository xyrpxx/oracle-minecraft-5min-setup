@echo off
REM ============================================================
REM  oracle-minecraft-5min-setup — lanceur Windows (double-clic)
REM  Ouvre Git Bash puis demarre setup.sh en Mode guide.
REM ============================================================
title Serveur Minecraft - Installation
echo.
echo   Bonjour ! On va installer ton serveur Minecraft gratuit :)
echo.
where bash >nul 2>nul
if errorlevel 1 (
    echo   [!] Il te manque "Git pour Windows" \(le terminal necessaire\).
    echo.
    echo   1. Ouvre https://git-scm.com/download/win
    echo   2. Telecharge et installe \(clic suivant, suivant, terminer\)
    echo   3. Revient dans ce dossier et re-double-clique sur ce fichier
    echo.
    pause
    exit /b 1
)
cd /d "%~dp0"
bash --login -i ./setup.sh
echo.
echo   \(La fenetre peut se fermer maintenant. Pour relancer : re-double-clique sur start-windows.bat\)
pause
