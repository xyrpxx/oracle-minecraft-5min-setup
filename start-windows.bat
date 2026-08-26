@echo off
REM ============================================================
REM  oracle-minecraft-5min-setup - Windows launcher
REM  Lanceur Windows : ouvre Git Bash puis lance setup.sh.
REM
REM  Requis : Git for Windows (https://git-scm.com/download/win).
REM  NE PAS utiliser WSL bash (mauvais interpréteur).
REM
REM  Double-clique ce fichier, puis suis les instructions a l'ecran.
REM  Required: Git for Windows from https://git-scm.com/download/win.
REM  Double-click this file, then follow the instructions.
REM ============================================================
title Minecraft Server - Setup
chcp 65001 >nul 2>&1
echo.
echo   Hello! / Bonjour !
echo   Lets install your FREE Minecraft server :)
echo   Installation de ton serveur Minecraft gratuit...
echo.

REM --- Locate Git Bash (NOT WSL bash) ---
set "GIT_BASH="

REM Priority 1: Git Bash from standard Program Files paths
if exist "C:\Program Files\Git\bin\bash.exe" (
    set "GIT_BASH=C:\Program Files\Git\bin\bash.exe"
    goto :verify_bash
)
if exist "C:\Program Files (x86)\Git\bin\bash.exe" (
    set "GIT_BASH=C:\Program Files (x86)\Git\bin\bash.exe"
    goto :verify_bash
)
if exist "%LOCALAPPDATA%\Programs\Git\bin\bash.exe" (
    set "GIT_BASH=%LOCALAPPDATA%\Programs\Git\bin\bash.exe"
    goto :verify_bash
)

REM Priority 2: Search PATH for any bash.exe in a "Git" folder
for /f "delims=" %%i in ('where bash.exe 2^>nul') do (
    echo "%%i" | findstr /I /C:"\Git\" >nul 2>&1
    if not errorlevel 1 (
        set "GIT_BASH=%%i"
        goto :verify_bash
    )
)

REM Nothing found: explain and exit cleanly
echo.
echo   [EN] Git for Windows is required but not found.
echo        1. Download: https://git-scm.com/download/win
echo        2. Install with default options (Next, Next, Finish)
echo        3. Double-click this file again
echo.
echo   [FR] Git pour Windows est requis mais introuvable.
echo        1. Telecharge : https://git-scm.com/download/win
echo        2. Installe avec les options par defaut (Suivant, Terminer)
echo        3. Re-double-clique sur ce fichier
echo.
pause
exit /b 1

:verify_bash
REM Make sure the bash we found is MSYS/Git (not WSL)
REM Run "uname -s" inside it and reject anything that says Linux.
set "MSYS_OK="
for /f "delims=" %%u in ('"%GIT_BASH%" -c "uname -s" 2^>nul') do set "MSYS_OK=%%u"
if /I "%MSYS_OK%"=="MINGW64" goto :found_bash
if /I "%MSYS_OK%"=="MINGW32" goto :found_bash
if /I "%MSYS_OK%"=="MSYS"    goto :found_bash
if /I "%MSYS_OK%"=="CYGWIN_NT-10.0" goto :found_bash

echo.
echo   [EN] Found a bash, but it is WSL bash, not Git Bash.
echo        Git for Windows is required.
echo        Download: https://git-scm.com/download/win
echo.
echo   [FR] Bash detecte, mais c'est celui de WSL. Git Bash est requis.
echo        Telecharge : https://git-scm.com/download/win
echo.
pause
exit /b 1

:found_bash
echo   [OK] Git Bash detecte : %GIT_BASH%

REM Change to the directory of this .bat file
cd /d "%~dp0"

REM Verify setup.sh is present
if not exist "setup.sh" (
    echo.
    echo   [EN] ERROR: setup.sh not found in: %CD%
    echo        Make sure you extracted ALL files from the zip.
    echo.
    echo   [FR] ERREUR : setup.sh introuvable dans : %CD%
    echo        Verifie que tu as bien extrait TOUS les fichiers du zip.
    echo.
    pause
    exit /b 1
)
echo   [OK] setup.sh trouve.
echo.
echo   Lancement du setup... (la fenetre peut prendre quelques secondes)
echo   Launching setup... (the window may take a few seconds)
echo.

REM Launch setup.sh in interactive mode (colors + prompts work)
"%GIT_BASH%" --login -i ./setup.sh
set "EXIT_CODE=%ERRORLEVEL%"

REM If interactive mode failed, retry without -i (rare)
if %EXIT_CODE% neq 0 (
    echo.
    echo   [EN] Retrying in non-interactive mode...
    echo   [FR] Nouvelle tentative en mode non-interactif...
    echo.
    "%GIT_BASH%" --login ./setup.sh
    set "EXIT_CODE=%ERRORLEVEL%"
)

echo.
echo ============================================================
if %EXIT_CODE% neq 0 (
    echo   [EN] Setup ended with code %EXIT_CODE%. Check the messages above.
    echo   [FR] Le setup s'est termine avec le code %EXIT_CODE%. Lis les messages ci-dessus.
) else (
    echo   [EN] Done! Your server is ready at the IP shown above.
    echo   [FR] Termine ! Ton serveur est pret a l'IP affichee plus haut.
)
echo ============================================================
echo.
echo   [EN] Press any key to close this window...
echo   [FR] Appuie sur une touche pour fermer cette fenetre...
pause >nul
