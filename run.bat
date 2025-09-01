@echo off
setlocal
REM Run from this script's directory
cd /d "%~dp0"

REM Target script path
set "SCRIPT=%~dp0app\scripts\run_proxy.ps1"
if not exist "%SCRIPT%" (
  echo ERROR: Cannot find PowerShell script at "%SCRIPT%"
  exit /b 1
)

REM Detect PowerShell 7 (pwsh)
set "POWERSHELL="
set "HAS_PWSH=0"
if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" (
  set "POWERSHELL=%ProgramFiles%\PowerShell\7\pwsh.exe"
  set "HAS_PWSH=1"
) else if exist "%ProgramFiles%\PowerShell\7-preview\pwsh.exe" (
  set "POWERSHELL=%ProgramFiles%\PowerShell\7-preview\pwsh.exe"
  set "HAS_PWSH=1"
) else (
  where pwsh.exe >nul 2>nul
  if not errorlevel 1 (
    set "POWERSHELL=pwsh.exe"
    set "HAS_PWSH=1"
  )
)

if "%HAS_PWSH%"=="0" (
  echo PowerShell 7 ^(pwsh^) is not installed or not found in PATH.
  set /p INSTALLPWSH=Install PowerShell 7 now? ^(y/n^): 
  if /I "%INSTALLPWSH%"=="y" goto install_pwsh
  if /I "%INSTALLPWSH%"=="yes" goto install_pwsh
  echo PowerShell 7 is required. Exiting.
  exit /b 1
)
goto launch

:install_pwsh
REM Try installing via winget if available; otherwise open the download page and exit
where winget >nul 2>nul
if errorlevel 1 (
  echo winget is not available. Opening the PowerShell download page...
  start "" https://github.com/PowerShell/PowerShell/releases/latest
  echo Please install PowerShell 7, then re-run this script.
  exit /b 1
) else (
  echo Installing PowerShell 7 via winget ^(this may prompt for elevation^)...
  winget install --id Microsoft.PowerShell -e --accept-package-agreements --accept-source-agreements --silent
)

REM Re-detect pwsh after attempted install
set "POWERSHELL="
set "HAS_PWSH=0"
if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" (
  set "POWERSHELL=%ProgramFiles%\PowerShell\7\pwsh.exe"
  set "HAS_PWSH=1"
) else if exist "%ProgramFiles%\PowerShell\7-preview\pwsh.exe" (
  set "POWERSHELL=%ProgramFiles%\PowerShell\7-preview\pwsh.exe"
  set "HAS_PWSH=1"
) else (
  where pwsh.exe >nul 2>nul
  if not errorlevel 1 (
    set "POWERSHELL=pwsh.exe"
    set "HAS_PWSH=1"
  )
)

if "%HAS_PWSH%"=="0" (
  echo PowerShell 7 installation did not complete or is not yet available.
  echo Please complete the installation and re-run this script.
  exit /b 1
)
goto launch

:launch

REM Launch in a new window to avoid the "Terminate batch job (Y/N)?" prompt
start "Scrapitor Proxy" "%POWERSHELL%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
exit /b 0