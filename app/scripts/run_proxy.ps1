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

# Verify the "py" launcher has a usable Python installed
function Test-PyLauncher {
    try {
        $out = & py -3 -c "import sys;print(sys.version)" 2>$null
        return ($LASTEXITCODE -eq 0 -and [string]::IsNullOrWhiteSpace($out) -eq $false)
    } catch { return $false }
}

# Verify a given python.exe path is runnable
function Test-PythonPath {
    param(
        [Parameter(Mandatory = $true)][string]$PythonExe
    )
    try {
        $out = & $PythonExe -c "import sys;print(sys.version)" 2>$null
        return ($LASTEXITCODE -eq 0 -and [string]::IsNullOrWhiteSpace($out) -eq $false)
    } catch { return $false }
}

# Resolve a usable Python interpreter without triggering Windows Store stubs
function Get-UsablePython {
    param(
        [Parameter(Mandatory)] [string] $VenvPython
    )
    
    # Prefer existing venv
    if (Test-Path $VenvPython) { return $VenvPython }
    
    # Try py launcher (skips Windows Store stub)
    $pyCmd = Get-Command py -ErrorAction SilentlyContinue
    if ($pyCmd -and $pyCmd.Source -notmatch 'WindowsApps' -and (Test-PyLauncher)) {
        return 'py'
    }
    
    # Try python/python3 directly
    foreach ($name in @('python', 'python3')) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd -and $cmd.Source -notmatch 'WindowsApps' -and (Test-PythonPath $cmd.Source)) {
            return $cmd.Source
        }
    }
    
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

# Wait for user acknowledgment before closing (for error cases)
function Wait-ForClose {
    Write-Host ""
    Read-Host "Press Enter to close" | Out-Null
}

# Start a background process with optional console attachment
function Start-BackgroundProcess {
    param(
        [Parameter(Mandatory)] [string] $FilePath,
        [Parameter(Mandatory)] [string[]] $Arguments,
        [string] $LogOut,
        [string] $LogErr,
        [switch] $AttachToConsole
    )
    
    $params = @{
        FilePath = $FilePath
        ArgumentList = $Arguments
        PassThru = $true
    }
    
    if ($LogOut) { $params.RedirectStandardOutput = $LogOut }
    if ($LogErr) { $params.RedirectStandardError = $LogErr }
    
    if ($AttachToConsole) {
        $params.NoNewWindow = $true
    } else {
        $params.WindowStyle = 'Hidden'
    }
    
    return Start-Process @params
}

# Display contents of a log file with a header
function Show-LogFile {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $Label
    )
    
    if (Test-Path $Path) {
        $content = Get-Content $Path -ErrorAction SilentlyContinue
        if ($content) {
            Write-Host ""
            Write-ColorOutput "${Label}:" -Color Yellow
            $content | ForEach-Object { Write-Host "  $_" }
        }
    }
}


# Wait for tunnel URL to appear in log files
function Wait-ForTunnelUrl {
    param(
        [Parameter(Mandatory)] [string] $LogOut,
        [Parameter(Mandatory)] [string] $LogErr,
        [int] $TimeoutSeconds = 120,
        [switch] $ShowProgress,
        [System.Diagnostics.Process] $Process
    )
    
    $startTime = Get-Date
    $timeoutTime = $startTime.AddSeconds($TimeoutSeconds)
    $lastSizeOut = 0
    $lastSizeErr = 0
    $urlPattern = 'https://[a-zA-Z0-9-]+\.trycloudflare\.com'
    
    while ((Get-Date) -lt $timeoutTime) {
        # If the tunnel process already exited, don't wait out the full timeout.
        if ($Process -and $Process.HasExited) {
            if ($ShowProgress) { Write-Host "`r                              `r" -NoNewline }
            return $null
        }
        # Check stdout
        if (Test-Path $LogOut) {
            $fileInfo = Get-Item $LogOut
            if ($fileInfo.Length -gt $lastSizeOut) {
                $content = Get-Content $LogOut -Raw -ErrorAction SilentlyContinue
                $lastSizeOut = $fileInfo.Length
                if ($content -match $urlPattern) {
                    return $matches[0].Trim()
                }
            }
        }
        
        # Check stderr
        if (Test-Path $LogErr) {
            $fileInfo = Get-Item $LogErr
            if ($fileInfo.Length -gt $lastSizeErr) {
                $content = Get-Content $LogErr -Raw -ErrorAction SilentlyContinue
                $lastSizeErr = $fileInfo.Length
                if ($content -match $urlPattern) {
                    return $matches[0].Trim()
                }
            }
        }
        
        if ($ShowProgress) {
            $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds)
            Write-Host "`rWaiting... $elapsed seconds" -NoNewline
        }
        
        Start-Sleep -Milliseconds 500
    }
    
    if ($ShowProgress) {
        Write-Host "`r                              `r" -NoNewline
    }
    
    return $null
}

# Create log directory if it doesn't exist
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
    Wait-ForClose
    return
}

# Ensure virtualenv exists (only after we confirmed Python is present)
$VenvJustCreated = $false
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
        Wait-ForClose
        return
    }
    $VenvJustCreated = $true
}

# Upgrade pip and install requirements (quiet, concise)
try {
    Write-ColorOutput "Checking dependencies..." -Color Cyan
    if ($VenvJustCreated) {
        $null = & $VenvPython -m pip install --disable-pip-version-check --no-color --upgrade pip setuptools wheel 2>$null
    }
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
    Write-Host ""
    Write-ColorOutput "The window will remain open so you can review the logs." -Color Yellow
    Wait-ForClose
    exit 1
}

# Derive port from env or config.yaml if present
try {
    $envPort = [Environment]::GetEnvironmentVariable('PROXY_PORT', 'Process')
    if (-not $envPort) { $envPort = [Environment]::GetEnvironmentVariable('PROXY_PORT', 'User') }
    if (-not $envPort) { $envPort = [Environment]::GetEnvironmentVariable('PROXY_PORT', 'Machine') }
    if ($envPort) {
        $Port = [int]$envPort
    } else {
        # Prefer app/config.yaml (matches Docker + docs), fall back to repo-root config.yaml.
        $configCandidates = @(
            (Join-Path $AppRoot 'config.yaml'),
            (Join-Path $RepoRoot 'config.yaml'),
            'config.yaml'
        ) | Select-Object -Unique

        $configPath = $null
        foreach ($p in $configCandidates) {
            if ($p -and (Test-Path $p)) { $configPath = $p; break }
        }

        if ($configPath) {
            $yaml = Get-Content $configPath -Raw -ErrorAction Stop
            if ($yaml -match '(?ms)server:\s*.*?\bport\s*:\s*(\d+)') {
                $Port = [int]$matches[1]
            }
        }
    }
} catch { }

# Ensure the Flask process uses the same port we use for health/tunnel checks.
$env:PROXY_PORT = "$Port"

# Optional timeout overrides (seconds)
try {
    $envTunnelTimeout = [Environment]::GetEnvironmentVariable('TUNNEL_TIMEOUT', 'Process')
    if (-not $envTunnelTimeout) { $envTunnelTimeout = [Environment]::GetEnvironmentVariable('TUNNEL_TIMEOUT', 'User') }
    if (-not $envTunnelTimeout) { $envTunnelTimeout = [Environment]::GetEnvironmentVariable('TUNNEL_TIMEOUT', 'Machine') }
    if ($envTunnelTimeout) { $Timeout = [int]$envTunnelTimeout }

    $envHealthTimeout = [Environment]::GetEnvironmentVariable('HEALTH_TIMEOUT', 'Process')
    if (-not $envHealthTimeout) { $envHealthTimeout = [Environment]::GetEnvironmentVariable('HEALTH_TIMEOUT', 'User') }
    if (-not $envHealthTimeout) { $envHealthTimeout = [Environment]::GetEnvironmentVariable('HEALTH_TIMEOUT', 'Machine') }
    if ($envHealthTimeout) { $HealthTimeout = [int]$envHealthTimeout }
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

# Build frontend if needed (Svelte SPA)
$FrontendDir = Join-Path $RepoRoot "frontend"
$SpaDistDir = Join-Path $AppRoot "static\dist"
$SpaIndexHtml = Join-Path $SpaDistDir "index.html"

if (Test-Path $FrontendDir) {
    $needsBuild = $false
    
    # Check if dist doesn't exist
    if (-not (Test-Path $SpaIndexHtml)) {
        $needsBuild = $true
        Write-ColorOutput "Frontend build not found, will build..." -Color Cyan
    } else {
        # Check if source is newer than build
        $srcDir = Join-Path $FrontendDir "src"
        if (Test-Path $srcDir) {
            $newestSrc = Get-ChildItem -Path $srcDir -Recurse -File | 
                Sort-Object LastWriteTime -Descending | 
                Select-Object -First 1
            $distTime = (Get-Item $SpaIndexHtml).LastWriteTime
            if ($newestSrc -and $newestSrc.LastWriteTime -gt $distTime) {
                $needsBuild = $true
                Write-ColorOutput "Frontend source changed, will rebuild..." -Color Cyan
            }
        }
    }
    
    if ($needsBuild) {
        # Check if npm is available
        $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
        if ($npmCmd) {
            Push-Location $FrontendDir
            try {
                # Install dependencies if needed
                $nodeModules = Join-Path $FrontendDir "node_modules"
                if (-not (Test-Path $nodeModules)) {
                    Write-ColorOutput "Installing frontend dependencies..." -Color Cyan
                    npm install --silent 2>$null
                    if ($LASTEXITCODE -ne 0) {
                        Write-ColorOutput "WARNING: npm install failed, continuing without frontend build" -Color Yellow
                    }
                }
                
                # Build
                if (Test-Path $nodeModules) {
                    Write-ColorOutput "Building frontend (Svelte SPA)..." -Color Cyan
                    npm run build 2>$null
                    if ($LASTEXITCODE -eq 0) {
                        Write-ColorOutput "Frontend build complete" -Color Green
                    } else {
                        Write-ColorOutput "WARNING: Frontend build failed, will use legacy templates" -Color Yellow
                    }
                }
            } finally {
                Pop-Location
            }
        } else {
            Write-ColorOutput "Node.js not found, skipping frontend build (using legacy templates)" -Color Yellow
        }
    } else {
        Write-ColorOutput "Frontend is up to date" -Color Green
    }
}

# Stop previous instances of THIS app (not all Python processes!)
try {
    $stoppedAny = $false
    
    # Stop cloudflared instances bound to our port
    Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^cloudflared(\.exe)?$' -and $_.CommandLine -match "--url\s+http://127\.0\.0\.1:$Port" } |
        ForEach-Object {
            Write-Host "  - Stopping previous cloudflared (PID: $($_.ProcessId))"
            Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
            $stoppedAny = $true
        }
    
    # Stop Python instances running our specific app from THIS repo's venv
    $venvPyPattern = [regex]::Escape($VenvPython)
    $venvPywPattern = [regex]::Escape($VenvPythonW)
    Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -match '^python(w)?(\.exe)?$' -and
            $_.CommandLine -match '-m\s+app\.server' -and
            (($_.CommandLine -match $venvPyPattern) -or ($_.CommandLine -match $venvPywPattern))
        } |
        ForEach-Object {
            Write-Host "  - Stopping previous Flask (PID: $($_.ProcessId))"
            Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
            $stoppedAny = $true
        }
    
    # Also try PIDs from previous run
    if (Test-Path $PidFile) {
        Get-Content $PidFile -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_ -match '^\d+$') {
                Stop-Process -Id ([int]$_) -Force -ErrorAction SilentlyContinue
            }
        }
        Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
    }
    
    if ($stoppedAny) { Start-Sleep -Milliseconds 500 }
} catch { }

Write-ColorOutput "Starting Flask server on port $Port..." -Color Cyan

# Start Flask in background
$env:PYTHONUNBUFFERED = "1"
$flaskOut = Join-Path $LogsDir 'flask.stdout.log'
$flaskErr = Join-Path $LogsDir 'flask.stderr.log'
try { Set-Content -Path $flaskOut -Value '' -NoNewline -Encoding utf8 } catch { }
try { Set-Content -Path $flaskErr -Value '' -NoNewline -Encoding utf8 } catch { }
$flaskExe = if ($AttachChildrenToConsole -or -not (Test-Path $VenvPythonW)) { $VenvPython } else { $VenvPythonW }

$flaskProcess = Start-BackgroundProcess `
    -FilePath $flaskExe `
    -Arguments @('-m', 'app.server') `
    -LogOut $flaskOut `
    -LogErr $flaskErr `
    -AttachToConsole:$AttachChildrenToConsole

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

if (-not $healthOk) {
    Write-ColorOutput "ERROR: Flask server failed to start or /health not responding" -Color Red
    Write-Host "Check if port $Port is already in use or if there are import errors in app.server"
    Show-LogFile -Path $flaskOut -Label "Flask stdout"
    Show-LogFile -Path $flaskErr -Label "Flask stderr"
    if ($flaskProcess -and !$flaskProcess.HasExited) { Stop-Process -Id $flaskProcess.Id -Force -ErrorAction SilentlyContinue }
    Write-Host ""
    Write-ColorOutput "The window will remain open so you can review the logs." -Color Yellow
    Wait-ForClose
    exit 1
}

Write-ColorOutput "Starting Cloudflare tunnel..." -Color Cyan

# Find cloudflared executable
$cfExe = (Get-Command (Join-Path $PSScriptRoot "cloudflared.exe") -ErrorAction SilentlyContinue)
if (-not $cfExe) { $cfExe = (Get-Command cloudflared -ErrorAction SilentlyContinue) }

# Build cloudflared arguments
$cfFlags = $env:CLOUDFLARED_FLAGS
if (-not $cfFlags -or [string]::IsNullOrWhiteSpace($cfFlags)) {
    # Fast default: avoid HA + forced QUIC (can delay startup on some networks)
    # Users can override via $env:CLOUDFLARED_FLAGS if they want different behavior.
    # IMPORTANT: keep loglevel at info so the tunnel URL is printed (we parse it from logs).
    $cfFlags = "--edge-ip-version 4 --loglevel info"
}
$cfArgList = @('tunnel','--no-autoupdate') + ($cfFlags -split '\s+') + @('--url', "http://127.0.0.1:$Port")

# Try up to 2 attempts to start tunnel and verify URL
$url = $null
$tunnelLogOut = $null
$tunnelLogErr = $null
$cloudflaredProcess = $null
$MaxAttempts = 2

for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
    # Clean up previous attempt
    if ($cloudflaredProcess -and !$cloudflaredProcess.HasExited) {
        Stop-Process -Id $cloudflaredProcess.Id -Force -ErrorAction SilentlyContinue
    }
    
    # Logs live under app/var/logs (same as server.py)
    $tunnelLogOut = Join-Path $LogsDir 'cloudflared.stdout.log'
    $tunnelLogErr = Join-Path $LogsDir 'cloudflared.stderr.log'
    try { Set-Content -Path $tunnelLogOut -Value '' -NoNewline -Encoding utf8 } catch { }
    try { Set-Content -Path $tunnelLogErr -Value '' -NoNewline -Encoding utf8 } catch { }
    
    if ($attempt -gt 1) {
        Write-ColorOutput "Retrying tunnel (attempt $attempt of $MaxAttempts)..." -Color Yellow
    }
    
    # Start cloudflared
    $cloudflaredProcess = Start-BackgroundProcess `
        -FilePath $cfExe.Source `
        -Arguments $cfArgList `
        -LogOut $tunnelLogOut `
        -LogErr $tunnelLogErr `
        -AttachToConsole:$AttachChildrenToConsole
    
    Write-ColorOutput "Waiting for tunnel URL (timeout: ${Timeout}s)..." -Color Yellow
    
    # Wait for URL
    $url = Wait-ForTunnelUrl -LogOut $tunnelLogOut -LogErr $tunnelLogErr -TimeoutSeconds $Timeout -ShowProgress -Process $cloudflaredProcess
    
    if ($url) { break }

    if ($cloudflaredProcess -and $cloudflaredProcess.HasExited) {
        Write-ColorOutput "cloudflared exited before producing a URL (exit code: $($cloudflaredProcess.ExitCode))." -Color Red
        Show-LogFile -Path $tunnelLogOut -Label "Cloudflared stdout"
        Show-LogFile -Path $tunnelLogErr -Label "Cloudflared stderr"
    } else {
        Write-ColorOutput "No tunnel URL received" -Color Yellow
    }
}

# Define cleanup block (used by both success and failure paths)
$cleanupBlock = {
    if ($flaskProcess -and !$flaskProcess.HasExited) {
        Stop-Process -Id $flaskProcess.Id -Force -ErrorAction SilentlyContinue
        Write-Host "  - Stopped Flask server"
    }
    if ($cloudflaredProcess -and !$cloudflaredProcess.HasExited) {
        Stop-Process -Id $cloudflaredProcess.Id -Force -ErrorAction SilentlyContinue
        Write-Host "  - Stopped cloudflared tunnel"
    }
    # Clean up state files (keep logs in app/var/logs for debugging)
    @($PidFile, (Join-Path $StateDir 'tunnel_url.txt')) |
        Where-Object { $_ -and (Test-Path $_) } |
        ForEach-Object { Remove-Item $_ -Force -ErrorAction SilentlyContinue }
}

if (-not $url) {
    # === FAILURE PATH ===
    Write-ColorOutput "ERROR: Could not get tunnel URL within $Timeout seconds" -Color Red
    Show-LogFile -Path $tunnelLogOut -Label "Cloudflared stdout"
    Show-LogFile -Path $tunnelLogErr -Label "Cloudflared stderr"
    Write-Host ""
    Write-ColorOutput "Troubleshooting:" -Color Cyan
    Write-Host "  - Check if port $Port is already in use"
    Write-Host "  - Check your internet connection"
    Write-Host "  - Check Windows Firewall settings"
    Write-Host ""
    & $cleanupBlock
    Write-ColorOutput "The window will remain open so you can review the logs." -Color Yellow
    Wait-ForClose
    exit 1
}

# === SUCCESS PATH ===
Write-Host ""
Write-ColorOutput "SUCCESS! Proxy is running" -Color Green
Write-Host ""
Write-Host "=== Configuration ==="
Write-Host ""
Write-Host "JanitorAI API URL: " -NoNewline
Write-ColorOutput "$url/openrouter-cc" -Color Green
Write-Host ""
Write-Host "Dashboard URL (Cloudflare): " -NoNewline
Write-ColorOutput "$url" -Color Green
Write-ColorOutput "Note: trycloudflare DNS may take a few seconds to propagate. If it doesn't resolve yet, wait and refresh." -Color Yellow
Write-Host "Dashboard URL (Local): " -NoNewline
Write-ColorOutput "http://localhost:$Port" -Color Green
Write-Host ""
Write-Host "=== Setup Instructions ==="
Write-Host "• Initiate a chat with the desired character on JanitorAI."
Write-Host "• Click 'using proxy'; under 'proxy', add a configuration and name it anything."
Write-Host "• For model name, paste: mistralai/devstral-2512:free"
Write-Host "• Paste the Cloudflare URL (copied above) under 'Proxy URL.'"
Write-Host "• Click 'Save changes' then 'Save Settings' and refresh the page."
Write-Host "• Enter any sample message (e.g., 'hi'); the app will then receive the model data."
Write-Host ""
Write-ColorOutput "Press Ctrl+C to stop the server when finished" -Color Yellow
Write-Host ""

# Persist tunnel URL and PIDs
try { Set-Content -Path (Join-Path $StateDir 'tunnel_url.txt') -Value $url -NoNewline -Encoding UTF8 } catch {}
try { Set-Content -Path $PidFile -Value @($flaskProcess.Id, $cloudflaredProcess.Id) -Encoding ascii } catch {}

# Main loop - keep running until Ctrl+C or process exit
try {
    while ($true) {
        if ($flaskProcess.HasExited -or $cloudflaredProcess.HasExited) {
            Write-ColorOutput "ERROR: One of the processes has stopped unexpectedly" -Color Red
            & $cleanupBlock
            Wait-ForClose
            exit 1
        }
        Start-Sleep -Seconds 1
    }
}
finally {
    Write-Host ""
    Write-ColorOutput "Stopping..." -Color Yellow
    & $cleanupBlock
    Write-ColorOutput "Stopped." -Color Green
}