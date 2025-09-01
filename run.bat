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
  echo ERROR: PowerShell 7 ^(pwsh^) is required but was not found.
  echo.
  echo Install it with:
  echo    winget install --id Microsoft.PowerShell -e --accept-package-agreements --accept-source-agreements
  echo.
  echo After installation, re-run this script.
  echo.
  pause
  exit /b 1
)
goto launch

:launch

REM Launch in a new window and keep it open to show any errors
start /wait "Scrapitor Proxy" "%POWERSHELL%" -NoLogo -NoProfile -ExecutionPolicy Bypass -NoExit -File "%SCRIPT%"
exit /b 0