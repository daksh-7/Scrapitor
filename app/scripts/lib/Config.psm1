#Requires -Version 7.0
Set-StrictMode -Version Latest

# ══════════════════════════════════════════════════════════════════════════════
#  Config.psm1 - Configuration management for Scrapitor
# ══════════════════════════════════════════════════════════════════════════════

$script:Config = $null

function Get-ScrapitorConfig {
    [CmdletBinding()]
    param(
        [string]$AppRoot,
        [string]$RepoRoot
    )
    
    if ($script:Config) { return $script:Config }
    
    # Defaults
    $config = @{
        Port           = 5000
        TunnelTimeout  = 120
        HealthTimeout  = 30
        Verbose        = $false
        AutoInstall    = $true
        AttachConsole  = $true
    }
    
    # Load from environment variables (highest priority)
    $envMappings = @{
        'PROXY_PORT'      = @{ Key = 'Port'; Type = [int] }
        'TUNNEL_TIMEOUT'  = @{ Key = 'TunnelTimeout'; Type = [int] }
        'HEALTH_TIMEOUT'  = @{ Key = 'HealthTimeout'; Type = [int] }
        'SCRAPITOR_VERBOSE' = @{ Key = 'Verbose'; Type = [bool] }
        'SCRAPITOR_AUTO_INSTALL' = @{ Key = 'AutoInstall'; Type = [bool] }
    }
    
    foreach ($envVar in $envMappings.Keys) {
        $mapping = $envMappings[$envVar]
        $value = Get-EnvVar -Name $envVar
        
        if ($null -ne $value) {
            try {
                if ($mapping.Type -eq [bool]) {
                    $config[$mapping.Key] = $value -match '^(1|true|yes|on)$'
                }
                elseif ($mapping.Type -eq [int]) {
                    $config[$mapping.Key] = [int]$value
                }
                else {
                    $config[$mapping.Key] = $value
                }
            }
            catch { }
        }
    }
    
    # Try loading port from config.yaml
    if (-not (Get-EnvVar -Name 'PROXY_PORT')) {
        $yamlPort = Get-PortFromYaml -AppRoot $AppRoot -RepoRoot $RepoRoot
        if ($yamlPort) { $config.Port = $yamlPort }
    }
    
    # Compute paths
    $config.AppRoot = $AppRoot
    $config.RepoRoot = $RepoRoot
    $config.VarDir = Join-Path $AppRoot 'var'
    $config.LogsDir = Join-Path $config.VarDir 'logs'
    $config.StateDir = Join-Path $config.VarDir 'state'
    $config.VenvPath = Join-Path $AppRoot '.venv'
    $config.VenvPython = Join-Path $config.VenvPath 'Scripts\python.exe'
    $config.VenvPythonW = Join-Path $config.VenvPath 'Scripts\pythonw.exe'
    $config.PidFile = Join-Path $config.StateDir 'pids.txt'
    $config.TunnelUrlFile = Join-Path $config.StateDir 'tunnel_url.txt'
    $config.FrontendDir = Join-Path $RepoRoot 'frontend'
    $config.SpaDistDir = Join-Path $AppRoot 'static\dist'
    
    $script:Config = $config
    return $config
}

function Get-EnvVar {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name
    )
    
    # Check Process, User, Machine scopes in order
    foreach ($scope in @('Process', 'User', 'Machine')) {
        $value = [Environment]::GetEnvironmentVariable($Name, $scope)
        if ($value) { return $value }
    }
    return $null
}

function Get-PortFromYaml {
    [CmdletBinding()]
    param(
        [string]$AppRoot,
        [string]$RepoRoot
    )
    
    $candidates = @(
        (Join-Path $AppRoot 'config.yaml'),
        (Join-Path $RepoRoot 'config.yaml')
    ) | Where-Object { $_ } | Select-Object -Unique
    
    foreach ($path in $candidates) {
        if (Test-Path $path) {
            try {
                $yaml = Get-Content $path -Raw -ErrorAction Stop
                if ($yaml -match '(?ms)server:\s*.*?\bport\s*:\s*(\d+)') {
                    return [int]$matches[1]
                }
            }
            catch { }
        }
    }
    
    return $null
}

function Initialize-Directories {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Config
    )
    
    $dirs = @($Config.VarDir, $Config.LogsDir, $Config.StateDir)
    
    foreach ($dir in $dirs) {
        if (-not (Test-Path $dir)) {
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
        }
    }
}

function Set-RuntimeEnvironment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Config
    )
    
    # Ensure Flask uses the same port
    $env:PROXY_PORT = "$($Config.Port)"
    
    # Unbuffered Python output
    $env:PYTHONUNBUFFERED = "1"
}

# ── Export ────────────────────────────────────────────────────────────────────
Export-ModuleMember -Function @(
    'Get-ScrapitorConfig',
    'Get-EnvVar',
    'Initialize-Directories',
    'Set-RuntimeEnvironment'
)

