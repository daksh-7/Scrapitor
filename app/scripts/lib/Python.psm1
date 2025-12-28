#Requires -Version 7.0
Set-StrictMode -Version Latest

# ══════════════════════════════════════════════════════════════════════════════
#  Python.psm1 - Python environment management for Scrapitor
# ══════════════════════════════════════════════════════════════════════════════

# ── Python Detection ──────────────────────────────────────────────────────────

function Test-PyLauncher {
    [CmdletBinding()]
    param()
    
    try {
        $out = & py -3 -c "import sys;print(sys.version)" 2>$null
        return ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($out))
    }
    catch { return $false }
}

function Test-PythonPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$PythonExe
    )
    
    try {
        $out = & $PythonExe -c "import sys;print(sys.version)" 2>$null
        return ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($out))
    }
    catch { return $false }
}

function Get-PythonVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$PythonExe
    )
    
    try {
        if ($PythonExe -eq 'py') {
            $version = & py -3 -c "import sys;print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>$null
        }
        else {
            $version = & $PythonExe -c "import sys;print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>$null
        }
        return $version
    }
    catch { return "unknown" }
}

function Find-UsablePython {
    [CmdletBinding()]
    param(
        [string]$VenvPython
    )
    
    # Prefer existing venv
    if ($VenvPython -and (Test-Path $VenvPython)) {
        return @{
            Path = $VenvPython
            Source = 'venv'
            Version = Get-PythonVersion -PythonExe $VenvPython
        }
    }
    
    # Try py launcher (skips Windows Store stub)
    $pyCmd = Get-Command py -ErrorAction SilentlyContinue
    if ($pyCmd -and $pyCmd.Source -notmatch 'WindowsApps' -and (Test-PyLauncher)) {
        return @{
            Path = 'py'
            Source = 'launcher'
            Version = Get-PythonVersion -PythonExe 'py'
        }
    }
    
    # Try python/python3 directly
    foreach ($name in @('python', 'python3')) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd -and $cmd.Source -notmatch 'WindowsApps' -and (Test-PythonPath $cmd.Source)) {
            return @{
                Path = $cmd.Source
                Source = 'path'
                Version = Get-PythonVersion -PythonExe $cmd.Source
            }
        }
    }
    
    return $null
}

# ── Virtual Environment ───────────────────────────────────────────────────────

function New-PythonVenv {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$VenvPath,
        [Parameter(Mandatory)][string]$PythonPath
    )
    
    if ($PythonPath -eq 'py') {
        $result = py -3 -m venv $VenvPath 2>&1
    }
    else {
        $result = & $PythonPath -m venv $VenvPath 2>&1
    }
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create virtual environment: $result"
    }
    
    $venvPython = Join-Path $VenvPath 'Scripts\python.exe'
    if (-not (Test-Path $venvPython)) {
        throw "Virtual environment created but python.exe not found at expected location"
    }
    
    return $venvPython
}

function Test-VenvExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$VenvPath
    )
    
    $venvPython = Join-Path $VenvPath 'Scripts\python.exe'
    return (Test-Path $venvPython)
}

# ── Dependencies ──────────────────────────────────────────────────────────────

function Install-PythonDependencies {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$PythonExe,
        [Parameter(Mandatory)][string]$RequirementsPath,
        [switch]$UpgradePip,
        [switch]$Silent
    )
    
    $results = @{
        Success = $true
        UpgradedPip = $false
        InstalledPackages = 0
        AlreadyUpToDate = $false
        Error = $null
    }
    
    try {
        # Upgrade pip if requested
        if ($UpgradePip) {
            $null = & $PythonExe -m pip install --disable-pip-version-check --no-color --upgrade pip setuptools wheel 2>$null
            $results.UpgradedPip = ($LASTEXITCODE -eq 0)
        }
        
        # Install requirements
        $pipOutput = & $PythonExe -m pip install --disable-pip-version-check --no-color -r $RequirementsPath 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            $results.Success = $false
            $results.Error = ($pipOutput | Out-String)
            return $results
        }
        
        # Parse output for installed packages
        $installedMatch = $pipOutput | Select-String 'Successfully installed' | Select-Object -First 1
        if ($installedMatch) {
            $pkgList = ($installedMatch.Line -replace '^Successfully installed\s+', '').Trim()
            $results.InstalledPackages = ($pkgList -split '\s+').Count
        }
        else {
            $results.AlreadyUpToDate = $true
        }
    }
    catch {
        $results.Success = $false
        $results.Error = $_.Exception.Message
    }
    
    return $results
}

# ── Export ────────────────────────────────────────────────────────────────────
Export-ModuleMember -Function @(
    'Test-PyLauncher',
    'Test-PythonPath',
    'Get-PythonVersion',
    'Find-UsablePython',
    'New-PythonVenv',
    'Test-VenvExists',
    'Install-PythonDependencies'
)

