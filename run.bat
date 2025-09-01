@echo off
setlocal
REM Run from this script's directory
cd /d "%~dp0"

REM Prefer PowerShell 7 (pwsh) if available, fallback to Windows PowerShell
set "POWERSHELL=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "HAS_PWSH=0"
if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" (
  set "POWERSHELL=%ProgramFiles%\PowerShell\7\pwsh.exe"
  set "HAS_PWSH=1"
) else (
  where pwsh.exe >nul 2>nul
  if not errorlevel 1 (
    set "POWERSHELL=pwsh.exe"
    set "HAS_PWSH=1"
  )
)

if "%HAS_PWSH%"=="0" (
  echo PowerShell 7 ^(pwsh^) is not installed.
  set /p INSTALLPWSH=install powershell 7 now? y/n:
  if /I "%INSTALLPWSH%"=="y" goto install_pwsh
  if /I "%INSTALLPWSH%"=="yes" goto install_pwsh
)
goto launch

:install_pwsh
REM Try installing via winget if available; otherwise open the download page
where winget >nul 2>nul
if errorlevel 1 (
  echo winget is not available. Opening the PowerShell download page...
  start "" https://github.com/PowerShell/PowerShell/releases/latest
  echo Please install PowerShell 7, then re-run this script.
) else (
  echo Installing PowerShell 7 via winget ^(this may prompt for elevation^)...
  winget install --id Microsoft.PowerShell -e --accept-package-agreements --accept-source-agreements --silent
  if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" set "POWERSHELL=%ProgramFiles%\PowerShell\7\pwsh.exe"
)

:launch

REM Launch in a new window to avoid the "Terminate batch job (Y/N)?" prompt
start "JanDown Proxy" "%POWERSHELL%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0app\scripts\run_proxy.ps1"
exit /b 0