#Requires -Version 7.0
Set-StrictMode -Version Latest

# ══════════════════════════════════════════════════════════════════════════════
#  Tunnel.psm1 - Cloudflared tunnel management for Scrapitor
# ══════════════════════════════════════════════════════════════════════════════

# ── Detection ─────────────────────────────────────────────────────────────────

function Find-Cloudflared {
    [CmdletBinding()]
    param(
        [string]$ScriptDir
    )
    
    # Check local script directory first
    if ($ScriptDir) {
        $localPath = Join-Path $ScriptDir 'cloudflared.exe'
        if (Test-Path $localPath) {
            return @{
                Path = $localPath
                Source = 'local'
            }
        }
    }
    
    # Check PATH
    $cmd = Get-Command cloudflared -ErrorAction SilentlyContinue
    if ($cmd) {
        return @{
            Path = $cmd.Source
            Source = 'path'
        }
    }
    
    return $null
}

function Test-CloudflaredInstalled {
    [CmdletBinding()]
    param(
        [string]$ScriptDir
    )
    
    return $null -ne (Find-Cloudflared -ScriptDir $ScriptDir)
}

# ── Installation ──────────────────────────────────────────────────────────────

function Install-Cloudflared {
    [CmdletBinding()]
    param(
        [string]$TargetDir,
        [switch]$Silent
    )
    
    $result = @{
        Success = $false
        Method = $null
        Path = $null
        Error = $null
    }
    
    # Try winget first
    $hasWinget = Get-Command winget -ErrorAction SilentlyContinue
    if ($hasWinget) {
        try {
            $wingetArgs = @(
                'install', '-e', '--id', 'Cloudflare.cloudflared',
                '--source', 'winget',
                '--accept-package-agreements',
                '--accept-source-agreements'
            )
            if ($Silent) { $wingetArgs += '--silent' }
            
            $null = & winget @wingetArgs 2>&1
            
            # Verify installation
            $cmd = Get-Command cloudflared -ErrorAction SilentlyContinue
            if ($cmd) {
                $result.Success = $true
                $result.Method = 'winget'
                $result.Path = $cmd.Source
                return $result
            }
        }
        catch { }
    }
    
    # Fallback: direct download
    try {
        $dest = Join-Path $TargetDir 'cloudflared.exe'
        $url = 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe'
        
        Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -TimeoutSec 120
        
        if (Test-Path $dest) {
            $result.Success = $true
            $result.Method = 'download'
            $result.Path = $dest
            return $result
        }
    }
    catch {
        $result.Error = $_.Exception.Message
    }
    
    return $result
}

function Install-WingetIfMissing {
    [CmdletBinding()]
    param()
    
    $hasWinget = Get-Command winget -ErrorAction SilentlyContinue
    if ($hasWinget) { return $true }
    
    try {
        # Open Microsoft Store for App Installer
        Start-Process "ms-windows-store://pdp/?productid=9NBLGGH4NNS1" | Out-Null
        return $false  # User needs to install manually
    }
    catch {
        return $false
    }
}

# ── Tunnel Operations ─────────────────────────────────────────────────────────

function Get-CloudflaredArgs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][int]$Port,
        [string]$CustomFlags
    )
    
    $args = @('tunnel', '--no-autoupdate')
    
    if ($CustomFlags) {
        $args += ($CustomFlags -split '\s+')
    }
    else {
        # Fast defaults: avoid HA + forced QUIC (can delay startup on some networks)
        $args += @('--edge-ip-version', '4', '--loglevel', 'info')
    }
    
    $args += @('--url', "http://127.0.0.1:$Port")
    
    return $args
}

function Wait-ForTunnelUrl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$LogOut,
        [Parameter(Mandatory)][string]$LogErr,
        [int]$TimeoutSeconds = 120,
        [System.Diagnostics.Process]$Process
    )
    
    $startTime = Get-Date
    $endTime = $startTime.AddSeconds($TimeoutSeconds)
    $lastSizeOut = 0
    $lastSizeErr = 0
    $urlPattern = 'https://[a-zA-Z0-9-]+\.trycloudflare\.com'
    
    while ((Get-Date) -lt $endTime) {
        # Check if process died
        if ($Process -and $Process.HasExited) {
            return @{
                Success = $false
                Url = $null
                Error = "Cloudflared exited with code $($Process.ExitCode)"
                ElapsedSeconds = ((Get-Date) - $startTime).TotalSeconds
            }
        }
        
        # Check stdout
        if (Test-Path $LogOut) {
            $fileInfo = Get-Item $LogOut
            if ($fileInfo.Length -gt $lastSizeOut) {
                $content = Get-Content $LogOut -Raw -ErrorAction SilentlyContinue
                $lastSizeOut = $fileInfo.Length
                if ($content -match $urlPattern) {
                    return @{
                        Success = $true
                        Url = $matches[0].Trim()
                        Error = $null
                        ElapsedSeconds = ((Get-Date) - $startTime).TotalSeconds
                    }
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
                    return @{
                        Success = $true
                        Url = $matches[0].Trim()
                        Error = $null
                        ElapsedSeconds = ((Get-Date) - $startTime).TotalSeconds
                    }
                }
            }
        }
        
        Start-Sleep -Milliseconds 300
    }
    
    return @{
        Success = $false
        Url = $null
        Error = "Timed out waiting for tunnel URL"
        ElapsedSeconds = $TimeoutSeconds
    }
}

function Save-TunnelUrl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Url
    )
    
    try {
        Set-Content -Path $Path -Value $Url -NoNewline -Encoding UTF8
        return $true
    }
    catch {
        return $false
    }
}

# ── Export ────────────────────────────────────────────────────────────────────
Export-ModuleMember -Function @(
    'Find-Cloudflared',
    'Test-CloudflaredInstalled',
    'Install-Cloudflared',
    'Install-WingetIfMissing',
    'Get-CloudflaredArgs',
    'Wait-ForTunnelUrl',
    'Save-TunnelUrl'
)

