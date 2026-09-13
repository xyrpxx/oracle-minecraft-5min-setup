@echo off
REM ============================================================
REM  Minecraft Server Launcher — GUI (Windows)
REM  Ouvre le lanceur graphique (launcher/gui_launcher.py).
REM  Requiert : Python 3 + tkinter + Git for Windows (Git Bash).
REM  Le .exe optionnel se construit via launcher/BUILD-EXE.md.
REM ============================================================
title Minecraft Server - Launcher
cd /d "%~dp0\.."

where python >nul 2>&1
if %ERRORLEVEL%==0 (
    python launcher\gui_launcher.py
    exit /b %ERRORLEVEL%
)

if exist "C:\Program Files\Git\mingw64\bin\python3.exe" (
    "C:\Program Files\Git\mingw64\bin\python3.exe" launcher\gui_launcher.py
    exit /b %ERRORLEVEL%
)

echo.
echo   [EN] Python 3 is required for the graphical launcher.
echo        Option 1: install Python from https://www.python.org/downloads/
echo                   (tick "Add python.exe to PATH")
echo        Option 2: use the classic installer instead: start-windows.bat
echo.
echo   [FR] Python 3 est requis pour le lanceur graphique.
echo        Option 1 : installe Python depuis https://www.python.org/downloads/
echo                   (coche "Add python.exe to PATH")
echo        Option 2 : utilise l'installeur classique : start-windows.bat
echo.
pause
exit /b 1
