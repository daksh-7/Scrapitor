Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Always operate from the repo root directory
$AppRoot = Split-Path $PSScriptRoot -Parent
$RepoRoot = Split-Path $AppRoot -Parent
Set-Location -Path $RepoRoot

# Configuration
$Port = 5000
$Timeout = 120  # seconds to wait for tunnel
$HealthTimeout = 30  # seconds to wait for Flask /health

# Helper functions
function Write-ColorOutput {
    param (
        [string]$Message,
        [string]$Color = "White",
        [switch]$NoNewline
    )
    
    $params = @{
        Object = $Message
        ForegroundColor = $Color
        NoNewline = $NoNewline
    }
    Write-Host @params
}

# Resolve a usable Python interpreter without triggering Windows Store stubs
function Get-UsablePython {
    param(
        [Parameter(Mandatory = $true)][string]$VenvPython
    )
    if (Test-Path $VenvPython) { return $VenvPython }

    $pyCmd = Get-Command py -ErrorAction SilentlyContinue
    if ($pyCmd -and $pyCmd.Source -and ($pyCmd.Source -notmatch 'WindowsApps')) { return 'py' }
    $pyCmdExe = Get-Command py.exe -ErrorAction SilentlyContinue
    if ($pyCmdExe -and $pyCmdExe.Source -and ($pyCmdExe.Source -notmatch 'WindowsApps')) { return 'py' }

    $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
    if ($pythonCmd -and $pythonCmd.Source -and ($pythonCmd.Source -notmatch 'WindowsApps')) { return $pythonCmd.Source }

    $python3Cmd = Get-Command python3 -ErrorAction SilentlyContinue
    if ($python3Cmd -and $python3Cmd.Source -and ($python3Cmd.Source -notmatch 'WindowsApps')) { return $python3Cmd.Source }

    return $null
}

# Read a yes/no answer, accepting y/n/yes/no in any case
function Read-YesNo {
    param(
        [Parameter(Mandatory = $true)][string]$Prompt
    )
    while ($true) {
        $resp = (Read-Host $Prompt).Trim()
        if ($resp -match '^(?i:y|yes)$') { return $true }
        if ($resp -match '^(?i:n|no)$') { return $false }
    }
}

# Ensure winget exists. If not, offer to install via Microsoft Store (App Installer)
function Install-WingetIfMissing {
    $wg = Get-Command winget -ErrorAction SilentlyContinue
    if ($wg) { return $true }

    Write-ColorOutput "winget is not installed." -Color Yellow
    $doInstall = Read-YesNo -Prompt "install winget now? y/n"
    if (-not $doInstall) { return $false }

    try {
        Write-ColorOutput "Opening Microsoft Store for 'App Installer'..." -Color Cyan
        Start-Process "ms-windows-store://pdp/?productid=9NBLGGH4NNS1" | Out-Null
        Write-Host "Install 'App Installer', then return here and press Enter to continue..."
        [void][System.Console]::ReadLine()
    } catch {
        Write-ColorOutput "Could not open Microsoft Store. Please install winget (App Installer) manually." -Color Red
        Write-Host "Docs: https://github.com/microsoft/winget-cli"
        return $false
    }

    $wg2 = Get-Command winget -ErrorAction SilentlyContinue
    return [bool]$wg2
}

# Install cloudflared via winget if possible, else direct-download to the script directory
function Install-Cloudflared {
    param(
        [string]$TargetDir
    )

    $installed = (Get-Command (Join-Path $PSScriptRoot "cloudflared.exe") -ErrorAction SilentlyContinue) -or (Get-Command cloudflared -ErrorAction SilentlyContinue)
    if ($installed) { return $true }

    $hasWinget = Get-Command winget -ErrorAction SilentlyContinue
    if ($hasWinget) {
        try {
            Write-ColorOutput "Installing cloudflared via winget..." -Color Cyan
            winget install -e --id Cloudflare.cloudflared --source winget --accept-package-agreements --accept-source-agreements
        } catch {}
        $installed = (Get-Command cloudflared -ErrorAction SilentlyContinue)
        if ($installed) { return $true }
    }

    # Fallback: direct download latest x64 exe to local folder
    try {
        $dest = Join-Path $TargetDir 'cloudflared.exe'
        $url  = 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe'
        Write-ColorOutput "Downloading cloudflared from GitHub releases..." -Color Cyan
        Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -TimeoutSec 120
        if (Test-Path $dest) { return $true }
    } catch {}

    return $false
}

# Offer a friendly exit confirmation at the end
function Confirm-ExitPrompt {
    while ($true) {
        $ans = (Read-Host "confirm exit? y/n").Trim()
        if ($ans -match '^(?i:y|yes)$') { break }
        if ($ans -match '^(?i:n|no)$') { Write-Host "exit cancelled. this window will remain open." }
    }
}

function Show-Progress {
    param (
        [int]$Seconds,
        [string]$Message
    )
    
    $spinChars = @("|", "/", "-", "\")
    $startTime = Get-Date
    $endTime = $startTime.AddSeconds($Seconds)
    
    Write-Host "$Message " -NoNewline
    
    $i = 0
    while ((Get-Date) -lt $endTime) {
        $char = $spinChars[$i % 4]
        Write-Host "`r$Message $char" -NoNewline
        Start-Sleep -Milliseconds 250
        $i++
    }
    Write-Host "`r$Message [OK]" -ForegroundColor Green
}

# Verify that the Cloudflare URL resolves and responds before opening it
function Test-CloudflaredUrl {
    param (
        [Parameter(Mandatory = $true)] [string] $Url,
        [int] $Retries = 12,
        [int] $DelayMs = 500
    )

    try { $uri = [Uri]$Url } catch { return $false }
    $tunnelHost = $uri.Host

    for ($i = 0; $i -lt $Retries; $i++) {
        $dnsOk = $false
        try {
            $null = Resolve-DnsName -Name $tunnelHost -ErrorAction Stop
            $dnsOk = $true
        } catch {
            try {
                $ns = nslookup $tunnelHost 2>$null
                if ($LASTEXITCODE -eq 0 -and $ns) { $dnsOk = $true }
            } catch { }
        }

        if ($dnsOk) {
            try {
                $healthUrl = ($Url.TrimEnd('/') + '/health')
                $resp = Invoke-WebRequest -Uri $healthUrl -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
                if ($resp.StatusCode -eq 200) { return $true }
            } catch {
                try {
                    $resp2 = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
                    if ($resp2.StatusCode -ge 200 -and $resp2.StatusCode -lt 500) { return $true }
                } catch { }
            }
        }

        Start-Sleep -Milliseconds $DelayMs
    }

    return $false
}

# Create log directory if it doesn't exist
$AppRoot = Split-Path $PSScriptRoot -Parent
$VarDir = Join-Path $AppRoot 'var'
$LogsDir = Join-Path $VarDir 'logs'
$StateDir = Join-Path $VarDir 'state'
if (-not (Test-Path $VarDir)) { New-Item -Path $VarDir -ItemType Directory | Out-Null }
if (-not (Test-Path $LogsDir)) { New-Item -Path $LogsDir -ItemType Directory | Out-Null }
if (-not (Test-Path $StateDir)) { New-Item -Path $StateDir -ItemType Directory | Out-Null }
Write-ColorOutput "Runtime dirs ready ($LogsDir, $StateDir)" -Color Cyan

# Draw header
Write-Host ""
Write-ColorOutput "====== Janitor Local Proxy ======" -Color Yellow
Write-Host ""

# Resolve Python (prefer local venv, then py, then real python; avoid Windows Store stubs)
$VenvPython   = Join-Path $AppRoot ".venv\Scripts\python.exe"
$VenvPythonW  = Join-Path $AppRoot ".venv\Scripts\pythonw.exe"
$PidFile      = Join-Path $StateDir 'pids.txt'
$AttachChildrenToConsole = $true  # when true, children die with window close more reliably
$UsePython = Get-UsablePython -VenvPython $VenvPython

if (-not $UsePython) {
    Write-ColorOutput "Python is not installed or not available on PATH." -Color Red
    Write-Host "Download Python (Windows): https://www.python.org/downloads/"
    Write-Host "Important: During setup, enable 'Add python.exe to PATH'."
    Write-Host "After installing, re-run Scrapitor using run.bat."
    Confirm-ExitPrompt
    return
}

# Ensure virtualenv exists (only after we confirmed Python is present)
if (-not (Test-Path $VenvPython)) {
    Write-ColorOutput "Creating virtual environment (.venv)..." -Color Cyan
    $VenvPath = Join-Path $AppRoot '.venv'
    if ($UsePython -eq "py") {
        py -3 -m venv $VenvPath
    } else {
        & $UsePython -m venv $VenvPath
    }
    if (-not (Test-Path $VenvPython)) {
        Write-ColorOutput "ERROR: Failed to create virtual environment" -Color Red
        Confirm-ExitPrompt
        return
    }
}

# Upgrade pip and install requirements (quiet, concise)
try {
    Write-ColorOutput "Checking dependencies..." -Color Cyan
    $null = & $VenvPython -m pip install --disable-pip-version-check --no-color --upgrade pip setuptools wheel 2>$null
    $Requirements = Join-Path $AppRoot 'requirements.txt'
    $pipOutput = & $VenvPython -m pip install --disable-pip-version-check --no-color -r $Requirements 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "ERROR: Failed to install dependencies" -Color Red
        $pipOutput | ForEach-Object { Write-Host "  $_" }
        exit 1
    }
    $installedMatch = $pipOutput | Select-String 'Successfully installed' | Select-Object -First 1
    if ($installedMatch) {
        $pkgList = ($installedMatch.Line -replace '^Successfully installed\s+', '').Trim()
        $pkgCount = ($pkgList -split '\s+').Count
        Write-ColorOutput "Installed/updated $pkgCount packages" -Color Green
    } else {
        Write-ColorOutput "Dependencies are up to date" -Color Green
    }
} catch {
    Write-ColorOutput "ERROR: Failed to install dependencies" -Color Red
    if ($pipOutput) { $pipOutput | ForEach-Object { Write-Host "  $_" } } else { Write-Host $_ }
    exit 1
}

# Derive port from env or config.yaml if present
try {
    $envPort = [Environment]::GetEnvironmentVariable('PROXY_PORT', 'Process')
    if (-not $envPort) { $envPort = [Environment]::GetEnvironmentVariable('PROXY_PORT', 'User') }
    if (-not $envPort) { $envPort = [Environment]::GetEnvironmentVariable('PROXY_PORT', 'Machine') }
    if ($envPort) {
        $Port = [int]$envPort
    } elseif (Test-Path 'config.yaml') {
        $yaml = Get-Content 'config.yaml' -Raw -ErrorAction Stop
        if ($yaml -match '(?ms)server:\s*.*?\bport\s*:\s*(\d+)') {
            $Port = [int]$matches[1]
        }
    }
} catch { }

# Check if cloudflared is installed; if not, offer to install
$cloudflaredExists = (Get-Command (Join-Path $PSScriptRoot "cloudflared.exe") -ErrorAction SilentlyContinue) -or (Get-Command cloudflared -ErrorAction SilentlyContinue)
if (-not $cloudflaredExists) {
    Write-ColorOutput "cloudflared is not installed." -Color Yellow
    $installCf = Read-YesNo -Prompt "install cloudflared now? y/n"
    if ($installCf) {
        $hasWinget = Get-Command winget -ErrorAction SilentlyContinue
        if (-not $hasWinget) {
            if (-not (Install-WingetIfMissing)) {
                Write-ColorOutput "winget installation not completed. attempting direct download..." -Color Yellow
            }
        }
        if (-not (Install-Cloudflared -TargetDir $PSScriptRoot)) {
            Write-ColorOutput "ERROR: failed to install cloudflared automatically" -Color Red
            Write-Host "Manual install instructions:"
            Write-Host " - Winget: winget install -e --id Cloudflare.cloudflared"
            Write-Host " - Or download the EXE and place it next to this script as 'cloudflared.exe'"
            Write-Host "   https://github.com/cloudflare/cloudflared/releases/latest"
            exit 1
        }
        $cloudflaredExists = (Get-Command (Join-Path $PSScriptRoot "cloudflared.exe") -ErrorAction SilentlyContinue) -or (Get-Command cloudflared -ErrorAction SilentlyContinue)
    }
    if (-not $cloudflaredExists) {
        Write-ColorOutput "ERROR: cloudflared is not installed or not in PATH" -Color Red
        Write-Host "Please download and install cloudflared from:"
        Write-Host "https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation"
        exit 1
    }
}

# Check if Flask app exists
if (-not (Test-Path (Join-Path $AppRoot "server.py"))) {
    Write-ColorOutput "ERROR: app/server.py not found" -Color Red
    exit 1
}

# Stop previous instances
# Set this to $true to aggressively kill any running python/pythonw/cloudflared
$ForceClean = $true
try {
    $killedProcesses = $false
    # Cloudflared instances bound to our URL/port
    $cfToKill = Get-CimInstance Win32_Process |
        Where-Object { $_.Name -match '^cloudflared(\.exe)?$' -and $_.CommandLine -match "--url\s+http://localhost:$Port" }
    foreach ($p in $cfToKill) {
        Write-Host "  - Stopping cloudflared (PID: $($p.ProcessId))"
        Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
        $killedProcesses = $true
    }
    # Python running app.py in this directory
    $appPath = "-m app.server"
    $pyToKill = Get-CimInstance Win32_Process |
        Where-Object { ($_.Name -match '^python(w)?(\.exe)?$') -and ($_.CommandLine -match [regex]::Escape($appPath)) }
    foreach ($p in $pyToKill) {
        Write-Host "  - Stopping Flask (PID: $($p.ProcessId))"
        Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
        $killedProcesses = $true
    }
    if ($killedProcesses) { Start-Sleep -Seconds 1 }
    if ($ForceClean) {
        Write-ColorOutput "Force cleaning any python/cloudflared instances..." -Color Yellow
        Get-Process -Name python, pythonw, cloudflared -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 500
    }
    if (Test-Path $PidFile) { try { Get-Content $PidFile | ForEach-Object { if ($_ -match '^\d+$') { Stop-Process -Id [int]$_ -Force -ErrorAction SilentlyContinue } } } catch {} ; Remove-Item $PidFile -Force -ErrorAction SilentlyContinue }
} catch {}

Write-ColorOutput "Starting Flask server on port $Port..." -Color Cyan

# Start Flask in background using venv python (prefer windowless pythonw.exe)
$env:PYTHONUNBUFFERED = "1"
$flaskOut = [System.IO.Path]::GetTempFileName()
$flaskErr = [System.IO.Path]::GetTempFileName()
$flaskExe = $VenvPython
if (-not $AttachChildrenToConsole -and (Test-Path $VenvPythonW)) { $flaskExe = $VenvPythonW }
if ($AttachChildrenToConsole) {
    $flaskProcess = Start-Process -FilePath $flaskExe -ArgumentList '-m','app.server' -PassThru -NoNewWindow -RedirectStandardOutput $flaskOut -RedirectStandardError $flaskErr
} else {
    $flaskProcess = Start-Process -FilePath $flaskExe -ArgumentList '-m','app.server' -PassThru -WindowStyle Hidden -RedirectStandardOutput $flaskOut -RedirectStandardError $flaskErr
}

# Wait for health; try both 127.0.0.1 and localhost, and fall back to root
$healthOk = $false
$startHealth = Get-Date
while (-not $healthOk -and ((Get-Date) - $startHealth).TotalSeconds -lt $HealthTimeout) {
    Start-Sleep -Milliseconds 500
    foreach ($hostName in @("127.0.0.1", "localhost")) {
        try {
            $resp = Invoke-WebRequest -Uri "http://${hostName}:${Port}/health" -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
            if ($resp.StatusCode -eq 200) { $healthOk = $true; break }
        } catch { 
            try {
                $resp2 = Invoke-WebRequest -Uri "http://${hostName}:${Port}/" -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
                if ($resp2.StatusCode -eq 200) { $healthOk = $true; break }
            } catch { }
        }
    }
    if ($flaskProcess.HasExited) { break }
}

# If HTTP checks failed but Flask prints "Running on", consider healthy
if (-not $healthOk) {
    try {
        $outC = if (Test-Path $flaskOut) { Get-Content $flaskOut -Raw -ErrorAction SilentlyContinue } else { "" }
        $errC = if (Test-Path $flaskErr) { Get-Content $flaskErr -Raw -ErrorAction SilentlyContinue } else { "" }
        if (($outC + "`n" + $errC) -match "Running on http://") { $healthOk = $true }
    } catch { }
}

if (-not $healthOk) {
    Write-ColorOutput "ERROR: Flask server failed to start or /health not responding" -Color Red
    Write-Host "Check if port $Port is already in use or if there are import errors in app.server"
    if (Test-Path $flaskOut) {
        Write-ColorOutput "Flask stdout:" -Color Yellow
        Get-Content $flaskOut -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "  $_" }
    }
    if (Test-Path $flaskErr) {
        Write-ColorOutput "Flask stderr:" -Color Yellow
        Get-Content $flaskErr -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "  $_" }
    }
    try { if ($flaskProcess -and !$flaskProcess.HasExited) { Stop-Process -Id $flaskProcess.Id -Force } } catch {}
    exit 1
}

Write-ColorOutput "Starting Cloudflare tunnel..." -Color Cyan

# Create temporary files for cloudflared output
$tunnelLogOut = [System.IO.Path]::GetTempFileName()
$tunnelLogErr = [System.IO.Path]::GetTempFileName()

# Start cloudflared with separate output redirection
$cfExe = (Get-Command (Join-Path $PSScriptRoot "cloudflared.exe") -ErrorAction SilentlyContinue)
if (-not $cfExe) { $cfExe = (Get-Command cloudflared -ErrorAction SilentlyContinue) }

if ($AttachChildrenToConsole) {
    $cloudflaredProcess = Start-Process -FilePath $cfExe.Source `
        -ArgumentList "tunnel", "--no-autoupdate", "--url", "http://127.0.0.1:$Port" `
        -RedirectStandardOutput $tunnelLogOut `
        -RedirectStandardError $tunnelLogErr `
        -PassThru `
        -NoNewWindow
} else {
    $cloudflaredProcess = Start-Process -FilePath $cfExe.Source `
        -ArgumentList "tunnel", "--no-autoupdate", "--url", "http://127.0.0.1:$Port" `
        -RedirectStandardOutput $tunnelLogOut `
        -RedirectStandardError $tunnelLogErr `
        -PassThru `
        -WindowStyle Hidden
}

# Wait for the URL to appear in the log files
$url = $null
$startTime = Get-Date
$timeoutTime = $startTime.AddSeconds($Timeout)

Write-ColorOutput "Waiting for tunnel URL (timeout: ${Timeout}s)..." -Color Yellow

# Monitor both log files for the URL
$lastSizeOut = 0
$lastSizeErr = 0
while ((Get-Date) -lt $timeoutTime -and (-not $url)) {
    # Check stdout
    if (Test-Path $tunnelLogOut) {
        $fileInfo = Get-Item $tunnelLogOut
        if ($fileInfo.Length -gt $lastSizeOut) {
            $content = Get-Content $tunnelLogOut -Raw -ErrorAction SilentlyContinue
            $lastSizeOut = $fileInfo.Length
            
            # Try to match the URL
            if ($content -match 'https://[a-zA-Z0-9-]+\.trycloudflare\.com') {
                $url = ("$($matches[0])").Trim()
                if ($url) { break }
            }
        }
    }
    
    # Check stderr
    if (Test-Path $tunnelLogErr) {
        $fileInfo = Get-Item $tunnelLogErr
        if ($fileInfo.Length -gt $lastSizeErr) {
            $content = Get-Content $tunnelLogErr -Raw -ErrorAction SilentlyContinue
            $lastSizeErr = $fileInfo.Length
            
            # Try to match the URL
            if ($content -match 'https://[a-zA-Z0-9-]+\.trycloudflare\.com') {
                $url = ("$($matches[0])").Trim()
                if ($url) { break }
            }
        }
    }
    
    # Show progress
    $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds)
    Write-Host "`rWaiting... $elapsed seconds" -NoNewline
    
    Start-Sleep -Milliseconds 500
}

Write-Host "`r                                    " -NoNewline
Write-Host "`r" -NoNewline

if ($url -and $url.Trim()) {
    # Verify DNS/HTTP, and if it fails, restart cloudflared once and try again
    if (-not (Test-CloudflaredUrl -Url $url -Retries 40 -DelayMs 500)) {
        Write-ColorOutput "Tunnel URL failed DNS/HTTP check; restarting cloudflared once..." -Color Yellow
        try { if ($cloudflaredProcess -and !$cloudflaredProcess.HasExited) { Stop-Process -Id $cloudflaredProcess.Id -Force -ErrorAction SilentlyContinue } } catch {}
        if (Test-Path $tunnelLogOut) { Remove-Item $tunnelLogOut -Force -ErrorAction SilentlyContinue }
        if (Test-Path $tunnelLogErr) { Remove-Item $tunnelLogErr -Force -ErrorAction SilentlyContinue }

        # Recreate temp logs
        $tunnelLogOut = [System.IO.Path]::GetTempFileName()
        $tunnelLogErr = [System.IO.Path]::GetTempFileName()

        # Start cloudflared again
        if ($AttachChildrenToConsole) {
            $cloudflaredProcess = Start-Process -FilePath $cfExe.Source `
                -ArgumentList "tunnel", "--no-autoupdate", "--url", "http://127.0.0.1:$Port" `
                -RedirectStandardOutput $tunnelLogOut `
                -RedirectStandardError $tunnelLogErr `
                -PassThru `
                -NoNewWindow
        } else {
            $cloudflaredProcess = Start-Process -FilePath $cfExe.Source `
                -ArgumentList "tunnel", "--no-autoupdate", "--url", "http://127.0.0.1:$Port" `
                -RedirectStandardOutput $tunnelLogOut `
                -RedirectStandardError $tunnelLogErr `
                -PassThru `
                -WindowStyle Hidden
        }

        # Wait again for URL
        $url = $null
        $startTime = Get-Date
        $timeoutTime = $startTime.AddSeconds($Timeout)
        $lastSizeOut = 0
        $lastSizeErr = 0
        while ((Get-Date) -lt $timeoutTime -and (-not $url)) {
            if (Test-Path $tunnelLogOut) {
                $fileInfo = Get-Item $tunnelLogOut
                if ($fileInfo.Length -gt $lastSizeOut) {
                    $content = Get-Content $tunnelLogOut -Raw -ErrorAction SilentlyContinue
                    $lastSizeOut = $fileInfo.Length
                    if ($content -match 'https://[a-zA-Z0-9-]+\.trycloudflare\.com') { $url = ("$($matches[0])").Trim(); if ($url) { break } }
                }
            }
            if (Test-Path $tunnelLogErr) {
                $fileInfo = Get-Item $tunnelLogErr
                if ($fileInfo.Length -gt $lastSizeErr) {
                    $content = Get-Content $tunnelLogErr -Raw -ErrorAction SilentlyContinue
                    $lastSizeErr = $fileInfo.Length
                    if ($content -match 'https://[a-zA-Z0-9-]+\.trycloudflare\.com') { $url = ("$($matches[0])").Trim(); if ($url) { break } }
                }
            }
            Start-Sleep -Milliseconds 500
        }

        # Verify the new URL as well
        if ($url -and $url.Trim() -and -not (Test-CloudflaredUrl -Url $url -Retries 40 -DelayMs 500)) {
            $url = $null
        }
    }

    if (-not ($url -and $url.Trim())) {
        Write-ColorOutput "ERROR: Could not get tunnel URL within $Timeout seconds" -Color Red
        if (Test-Path $tunnelLogOut) {
            Write-Host ""
            Write-ColorOutput "Cloudflared stdout:" -Color Yellow
            Get-Content $tunnelLogOut | ForEach-Object { Write-Host "  $_" }
        }
        if (Test-Path $tunnelLogErr) {
            Write-Host ""
            Write-ColorOutput "Cloudflared stderr:" -Color Yellow
            Get-Content $tunnelLogErr | ForEach-Object { Write-Host "  $_" }
        }
        Write-Host ""
        Write-ColorOutput "Troubleshooting tips:" -Color Cyan
        Write-Host "  - Check if port $Port is already in use"
        Write-Host "  - Ensure cloudflared is correctly installed and in PATH"
        Write-Host "  - Check your internet connection"
        Write-Host "  - Try running the script as Administrator"
        Write-Host "  - Check Windows Firewall settings"

        if ($flaskProcess -and !$flaskProcess.HasExited) { Stop-Process -Id $flaskProcess.Id -Force -ErrorAction SilentlyContinue }
        if ($cloudflaredProcess -and !$cloudflaredProcess.HasExited) { Stop-Process -Id $cloudflaredProcess.Id -Force -ErrorAction SilentlyContinue }
        if (Test-Path $tunnelLogOut) { Remove-Item $tunnelLogOut -Force -ErrorAction SilentlyContinue }
        if (Test-Path $tunnelLogErr) { Remove-Item $tunnelLogErr -Force -ErrorAction SilentlyContinue }
        if (Test-Path $flaskOut) { Remove-Item $flaskOut -Force -ErrorAction SilentlyContinue }
        if (Test-Path $flaskErr) { Remove-Item $flaskErr -Force -ErrorAction SilentlyContinue }
        if (Test-Path $PidFile) { Remove-Item $PidFile -Force -ErrorAction SilentlyContinue }
        exit 1
    }

    Write-Host ""
    Write-ColorOutput "SUCCESS! Proxy is running" -Color Green
    Write-Host ""
    Write-Host "=== Configuration ==="
    Write-Host ""
    $apiUrl = if ($url -and $url.Trim()) { "$url/openrouter-cc" } else { "Unavailable" }
    Write-Host "JanitorAI API URL: " -NoNewline
    Write-ColorOutput "$apiUrl" -Color Green
    Write-Host ""
    Write-Host "Dashboard URL (Cloudflare): " -NoNewline
    Write-ColorOutput "$url" -Color Green
    if ($url -and $url.Trim()) { try { Start-Process $url } catch { } }
    Write-Host "Dashboard URL (Local): " -NoNewline
    Write-ColorOutput "http://localhost:$Port" -Color Green
    Write-Host ""
    Write-Host "=== Setup Instructions ==="
    Write-Host "• Initiate a chat with the desired character on JanitorAI."
    Write-Host "• Click 'using proxy'; under 'proxy', add a configuration and name it anything."
    Write-Host "• For model name, paste: mistralai/mistral-small-3.2-24b-instruct:free"
    Write-Host "• Paste the Cloudflare URL (copied above) under 'Proxy URL.'"
    Write-Host "• Click 'Save changes' then 'Save Settings' and refresh the page."
    Write-Host "• Enter any sample message (e.g., 'hi'); the app will then receive the model data."
    Write-Host ""
    Write-ColorOutput "Press Ctrl+C to stop the server when finished" -Color Yellow
    Write-Host ""

    # Persist tunnel URL for the UI/server to read
    try {
        Set-Content -Path (Join-Path $StateDir 'tunnel_url.txt') -Value $url -NoNewline -Encoding UTF8
    } catch {}
    try { Set-Content -Path $PidFile -Value @($flaskProcess.Id, $cloudflaredProcess.Id) -Encoding ascii } catch {}

    # Register cleanup handler
    $cleanupBlock = {
        Write-Host "`n"
        Write-ColorOutput "Stopping services..." -Color Yellow
        
        # Stop Flask
        if ($flaskProcess -and !$flaskProcess.HasExited) {
            Stop-Process -Id $flaskProcess.Id -Force -ErrorAction SilentlyContinue
            Write-Host "  - Stopped Flask server"
        }
        
        # Stop cloudflared
        if ($cloudflaredProcess -and !$cloudflaredProcess.HasExited) {
            Stop-Process -Id $cloudflaredProcess.Id -Force -ErrorAction SilentlyContinue
            Write-Host "  - Stopped cloudflared tunnel"
        }
        
        # Clean up any remaining processes
        Get-Process -Name python, python3, cloudflared -ErrorAction SilentlyContinue | 
            Stop-Process -Force -ErrorAction SilentlyContinue
        
        # Remove temp log files and persisted tunnel URL
        if (Test-Path $tunnelLogOut) {
            Remove-Item $tunnelLogOut -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path $tunnelLogErr) {
            Remove-Item $tunnelLogErr -Force -ErrorAction SilentlyContinue
        }
        $tunnelFile = Join-Path $StateDir 'tunnel_url.txt'
        if (Test-Path $tunnelFile) { Remove-Item $tunnelFile -Force -ErrorAction SilentlyContinue }
        if (Test-Path $flaskOut) { Remove-Item $flaskOut -Force -ErrorAction SilentlyContinue }
        if (Test-Path $flaskErr) { Remove-Item $flaskErr -Force -ErrorAction SilentlyContinue }
        if (Test-Path $PidFile) { Remove-Item $PidFile -Force -ErrorAction SilentlyContinue }
        
        Write-ColorOutput "All processes stopped." -Color Green
    }

    # Register the cleanup script block
    Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action $cleanupBlock | Out-Null

    # Keep the script running
    try {
        while ($true) {
            # Check if processes are still running
            if ($flaskProcess.HasExited -or $cloudflaredProcess.HasExited) {
                Write-ColorOutput "ERROR: One of the processes has stopped unexpectedly" -Color Red
                & $cleanupBlock
                exit 1
            }
            Start-Sleep -Seconds 1
        }
    }
    catch {
        # Ctrl+C was pressed
    }
    finally {
        & $cleanupBlock
        Confirm-ExitPrompt
    }
} else {
    Write-ColorOutput "ERROR: Could not get tunnel URL within $Timeout seconds" -Color Red
    
    # Show both cloudflared outputs for debugging
    if (Test-Path $tunnelLogOut) {
        Write-Host ""
        Write-ColorOutput "Cloudflared stdout:" -Color Yellow
        Get-Content $tunnelLogOut | ForEach-Object { 
            Write-Host "  $_" 
        }
    }
    
    if (Test-Path $tunnelLogErr) {
        Write-Host ""
        Write-ColorOutput "Cloudflared stderr:" -Color Yellow
        Get-Content $tunnelLogErr | ForEach-Object { 
            Write-Host "  $_" 
        }
    }
    
    # Provide troubleshooting tips
    Write-Host ""
    Write-ColorOutput "Troubleshooting tips:" -Color Cyan
    Write-Host "  - Check if port $Port is already in use"
    Write-Host "  - Ensure cloudflared is correctly installed and in PATH"
    Write-Host "  - Check your internet connection"
    Write-Host "  - Try running the script as Administrator"
    Write-Host "  - Check Windows Firewall settings"
    
    # Stop any running processes
    if ($flaskProcess -and !$flaskProcess.HasExited) {
        Stop-Process -Id $flaskProcess.Id -Force -ErrorAction SilentlyContinue
    }
    if ($cloudflaredProcess -and !$cloudflaredProcess.HasExited) {
        Stop-Process -Id $cloudflaredProcess.Id -Force -ErrorAction SilentlyContinue
    }
    
    # Remove temp log files
    if (Test-Path $tunnelLogOut) {
        Remove-Item $tunnelLogOut -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path $tunnelLogErr) {
        Remove-Item $tunnelLogErr -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path $flaskOut) { Remove-Item $flaskOut -Force -ErrorAction SilentlyContinue }
    if (Test-Path $flaskErr) { Remove-Item $flaskErr -Force -ErrorAction SilentlyContinue }
        if (Test-Path $PidFile) { Remove-Item $PidFile -Force -ErrorAction SilentlyContinue }
}

