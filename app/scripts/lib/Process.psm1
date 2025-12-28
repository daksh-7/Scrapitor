#Requires -Version 7.0
Set-StrictMode -Version Latest

# ══════════════════════════════════════════════════════════════════════════════
#  Process.psm1 - Process management for Scrapitor
# ══════════════════════════════════════════════════════════════════════════════

$script:ManagedProcesses = @{}

# ── Process Lifecycle ─────────────────────────────────────────────────────────

function Start-ManagedProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$Arguments,
        [string]$LogOut,
        [string]$LogErr,
        [switch]$AttachToConsole
    )
    
    # Clear log files
    if ($LogOut) { 
        try { Set-Content -Path $LogOut -Value '' -NoNewline -Encoding utf8 } catch { }
    }
    if ($LogErr) { 
        try { Set-Content -Path $LogErr -Value '' -NoNewline -Encoding utf8 } catch { }
    }
    
    $params = @{
        FilePath     = $FilePath
        ArgumentList = $Arguments
        PassThru     = $true
    }
    
    if ($LogOut) { $params.RedirectStandardOutput = $LogOut }
    if ($LogErr) { $params.RedirectStandardError = $LogErr }
    
    if ($AttachToConsole) {
        $params.NoNewWindow = $true
    }
    else {
        $params.WindowStyle = 'Hidden'
    }
    
    $process = Start-Process @params
    
    $script:ManagedProcesses[$Name] = @{
        Process   = $process
        Name      = $Name
        StartTime = Get-Date
        LogOut    = $LogOut
        LogErr    = $LogErr
    }
    
    return $process
}

function Stop-ManagedProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [int]$GracePeriodSeconds = 3
    )
    
    $managed = $script:ManagedProcesses[$Name]
    if (-not $managed) { return $false }
    
    $process = $managed.Process
    if (-not $process -or $process.HasExited) { 
        $script:ManagedProcesses.Remove($Name)
        return $true 
    }
    
    try {
        # Try graceful stop first (works for console apps)
        $process.CloseMainWindow() | Out-Null
        
        # Wait for graceful exit
        if (-not $process.WaitForExit($GracePeriodSeconds * 1000)) {
            # Force kill
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        }
        
        $script:ManagedProcesses.Remove($Name)
        return $true
    }
    catch {
        try {
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        }
        catch { }
        $script:ManagedProcesses.Remove($Name)
        return $false
    }
}

function Stop-AllManagedProcesses {
    [CmdletBinding()]
    param(
        [int]$GracePeriodSeconds = 3
    )
    
    $results = @{}
    foreach ($name in @($script:ManagedProcesses.Keys)) {
        $results[$name] = Stop-ManagedProcess -Name $name -GracePeriodSeconds $GracePeriodSeconds
    }
    return $results
}

function Test-ManagedProcessRunning {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name
    )
    
    $managed = $script:ManagedProcesses[$Name]
    if (-not $managed) { return $false }
    
    return (-not $managed.Process.HasExited)
}

function Get-ManagedProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name
    )
    
    return $script:ManagedProcesses[$Name]
}

# ── Cleanup Stale Processes ───────────────────────────────────────────────────

function Stop-StaleProcesses {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][int]$Port,
        [Parameter(Mandatory)][string]$VenvPython,
        [string]$VenvPythonW,
        [string]$PidFile
    )
    
    $stopped = @{
        Cloudflared = 0
        Flask = 0
        FromPidFile = 0
    }
    
    try {
        # Stop cloudflared instances bound to our port
        Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
            Where-Object { 
                $_.Name -match '^cloudflared(\.exe)?$' -and 
                $_.CommandLine -match "--url\s+http://127\.0\.0\.1:$Port" 
            } |
            ForEach-Object {
                Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
                $stopped.Cloudflared++
            }
        
        # Stop Python instances running our specific app
        $venvPyPattern = [regex]::Escape($VenvPython)
        $patterns = @($venvPyPattern)
        if ($VenvPythonW) {
            $patterns += [regex]::Escape($VenvPythonW)
        }
        
        Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Name -match '^python(w)?(\.exe)?$' -and
                $_.CommandLine -match '-m\s+app\.server' -and
                ($patterns | Where-Object { $_.CommandLine -match $_ })
            } |
            ForEach-Object {
                Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
                $stopped.Flask++
            }
        
        # Also try PIDs from previous run
        if ($PidFile -and (Test-Path $PidFile)) {
            Get-Content $PidFile -ErrorAction SilentlyContinue | ForEach-Object {
                if ($_ -match '^\d+$') {
                    try {
                        Stop-Process -Id ([int]$_) -Force -ErrorAction SilentlyContinue
                        $stopped.FromPidFile++
                    }
                    catch { }
                }
            }
            Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
        }
    }
    catch { }
    
    $totalStopped = $stopped.Cloudflared + $stopped.Flask + $stopped.FromPidFile
    if ($totalStopped -gt 0) {
        Start-Sleep -Milliseconds 500
    }
    
    return $stopped
}

# ── Health Checks ─────────────────────────────────────────────────────────────

function Wait-ForHealth {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][int]$Port,
        [int]$TimeoutSeconds = 30,
        [System.Diagnostics.Process]$Process
    )
    
    $startTime = Get-Date
    $endTime = $startTime.AddSeconds($TimeoutSeconds)
    
    while ((Get-Date) -lt $endTime) {
        # Check if process died
        if ($Process -and $Process.HasExited) {
            return @{
                Success = $false
                Error = "Process exited unexpectedly"
            }
        }
        
        foreach ($hostName in @("127.0.0.1", "localhost")) {
            try {
                $resp = Invoke-WebRequest -Uri "http://${hostName}:${Port}/health" -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
                if ($resp.StatusCode -eq 200) {
                    return @{
                        Success = $true
                        Host = $hostName
                        ResponseTime = ((Get-Date) - $startTime).TotalSeconds
                    }
                }
            }
            catch {
                # Try root as fallback
                try {
                    $resp = Invoke-WebRequest -Uri "http://${hostName}:${Port}/" -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
                    if ($resp.StatusCode -eq 200) {
                        return @{
                            Success = $true
                            Host = $hostName
                            ResponseTime = ((Get-Date) - $startTime).TotalSeconds
                        }
                    }
                }
                catch { }
            }
        }
        
        Start-Sleep -Milliseconds 500
    }
    
    return @{
        Success = $false
        Error = "Health check timed out after $TimeoutSeconds seconds"
    }
}

# ── PID File Management ───────────────────────────────────────────────────────

function Save-PidFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [int[]]$Pids
    )
    
    try {
        Set-Content -Path $Path -Value $Pids -Encoding ascii
        return $true
    }
    catch {
        return $false
    }
}

function Remove-PidFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path
    )
    
    if (Test-Path $Path) {
        Remove-Item $Path -Force -ErrorAction SilentlyContinue
    }
}

# ── Log File Utilities ────────────────────────────────────────────────────────

function Get-LogContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [int]$TailLines = 20
    )
    
    if (-not (Test-Path $Path)) { return @() }
    
    try {
        $content = Get-Content $Path -ErrorAction SilentlyContinue -Tail $TailLines
        return $content
    }
    catch {
        return @()
    }
}

# ── Export ────────────────────────────────────────────────────────────────────
Export-ModuleMember -Function @(
    'Start-ManagedProcess',
    'Stop-ManagedProcess',
    'Stop-AllManagedProcesses',
    'Test-ManagedProcessRunning',
    'Get-ManagedProcess',
    'Stop-StaleProcesses',
    'Wait-ForHealth',
    'Save-PidFile',
    'Remove-PidFile',
    'Get-LogContent'
)

