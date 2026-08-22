@echo off
REM ============================================================
REM  oracle-minecraft-5min-setup — Windows launcher (double-click)
REM  Lanceur Windows : ouvre Git Bash puis demarre setup.sh.
REM  The wizard language is auto-detected (English by default).
REM ============================================================
title Minecraft Server - Setup
echo.
echo   Hello! / Bonjour !
echo   Lets install your FREE Minecraft server :)
echo   Installation de ton serveur Minecraft gratuit...
echo.
where bash >nul 2>nul
if errorlevel 1 (
    echo   [EN] Missing "Git for Windows" \(the required terminal\).
    echo        1. Open https://git-scm.com/download/win
    echo        2. Download and install \(next, next, finish\)
    echo        3. Come back and double-click this file again
    echo   [FR] Il te manque "Git pour Windows" :
    echo        installe-le sur https://git-scm.com/download/win puis relance.
    echo.
    pause
    exit /b 1
)
cd /d "%~dp0"
bash --login -i ./setup.sh
echo.
echo   Done! \(To run again: double-click start-windows.bat\)
echo   \(La fenetre peut se fermer. Pour relancer : re-double-clique sur ce fichier\)
pause
