@echo off
setlocal EnableDelayedExpansion
cd /d "%~dp0"

:: ═══════════════════════════════════════════════════════════════════════════
::  Scrapitor Launcher
:: ═══════════════════════════════════════════════════════════════════════════

:: Silent git update (if available)
where git >nul 2>nul && if exist ".git" (
    git fetch --all --tags --prune >nul 2>nul
    git pull --rebase --autostash >nul 2>nul
)

:: Find PowerShell 7
set "PS="
if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" (
    set "PS=%ProgramFiles%\PowerShell\7\pwsh.exe"
) else if exist "%ProgramFiles%\PowerShell\7-preview\pwsh.exe" (
    set "PS=%ProgramFiles%\PowerShell\7-preview\pwsh.exe"
) else (
    where pwsh.exe >nul 2>nul && set "PS=pwsh.exe"
)

if not defined PS goto :no_pwsh

:: Launch Scrapitor
start "" "%PS%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0app\scripts\run_proxy.ps1"
exit /b 0

:: ═══════════════════════════════════════════════════════════════════════════
::  Error: PowerShell 7 Required
:: ═══════════════════════════════════════════════════════════════════════════
:no_pwsh
:: Generate ESC character for ANSI colors
for /f %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"

cls
echo.
echo   %ESC%[91m════════════════════════════════════════════════════════════%ESC%[0m
echo.
echo   %ESC%[91m  PowerShell 7 is required but was not found.%ESC%[0m
echo.
echo   %ESC%[93m  Install it with:%ESC%[0m
echo   %ESC%[96m  winget install Microsoft.PowerShell%ESC%[0m
echo.
echo   %ESC%[90m  Then re-run this script.%ESC%[0m
echo.
echo   %ESC%[91m════════════════════════════════════════════════════════════%ESC%[0m
echo.
pause
exit /b 1
