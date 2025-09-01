@echo off
setlocal
REM Run from this script's directory
cd /d "%~dp0"

REM Optional: Update repo if Git is available and this is a git clone
set "HAS_GIT=0"
where git >nul 2>nul
if not errorlevel 1 (
  set "HAS_GIT=1"
)

if "%HAS_GIT%"=="1" (
  if exist ".git" (
    echo Updating Scrapitor from origin...
    git fetch --all --tags --prune
    if errorlevel 1 (
      echo Git fetch failed. Proceeding without updating.
    ) else (
      git pull --rebase --autostash
      if errorlevel 1 echo Git pull failed ^(local changes or connectivity^). Proceeding without updating.
    )
  ) else (
    echo This folder is not a Git clone. To receive updates automatically, use Git:
    echo   winget install git.git
    echo   git clone https://github.com/daksh-7/Scrapitor
  )
) else (
  echo Git was not found. To update in the future, either:
  echo   - Download the latest ZIP: https://github.com/daksh-7/Scrapitor
  echo   - Or install Git: winget install git.git
)

REM Target script path
set "SCRIPT=%~dp0app\scripts\run_proxy.ps1"
if not exist "%SCRIPT%" (
  echo ERROR: Cannot find PowerShell script at "%SCRIPT%"
  echo.
  pause
  exit /b 1
)

REM Detect PowerShell 7 (pwsh)
set "POWERSHELL="
set "HAS_PWSH=0"
if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" (
  set "POWERSHELL=%ProgramFiles%\PowerShell\7\pwsh.exe"
  set "HAS_PWSH=1"
) else (
  if exist "%ProgramFiles%\PowerShell\7-preview\pwsh.exe" (
    set "POWERSHELL=%ProgramFiles%\PowerShell\7-preview\pwsh.exe"
    set "HAS_PWSH=1"
  ) else (
    where pwsh.exe >nul 2>nul
    if not errorlevel 1 (
      set "POWERSHELL=pwsh.exe"
      set "HAS_PWSH=1"
    )
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

REM Launch PowerShell in a separate window and close this batch to avoid
REM the "Terminate batch job (Y/N)?" prompt on close.
start "" "%POWERSHELL%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
exit /b 0