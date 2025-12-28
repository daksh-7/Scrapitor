#Requires -Version 7.0
Set-StrictMode -Version Latest

# ══════════════════════════════════════════════════════════════════════════════
#  UI.psm1 - Terminal UI components for Scrapitor
# ══════════════════════════════════════════════════════════════════════════════

# ── Theme ─────────────────────────────────────────────────────────────────────
$script:Theme = @{
    Primary   = 'Cyan'
    Success   = 'Green'
    Warning   = 'Yellow'
    Error     = 'Red'
    Muted     = 'DarkGray'
    Accent    = 'Magenta'
}

# ── ASCII Art Banner ──────────────────────────────────────────────────────────
$script:Banner = @'

     ____   ____  ____      _     ____   ___  _____  ___   ____  
    / ___| / ___||  _ \    / \   |  _ \ |_ _||_   _|/ _ \ |  _ \ 
    \___ \| |    | |_) |  / _ \  | |_) | | |   | | | | | || |_) |
     ___) | |___ |  _ <  / ___ \ |  __/  | |   | | | |_| ||  _ < 
    |____/ \____||_| \_\/_/   \_\|_|    |___|  |_|  \___/ |_| \_\
                                                                 
              ========================================
                       L O C A L   P R O X Y
              ========================================
'@

$script:BannerAlt = @'

    .d8888b.   .d8888b.  8888888b.         d8888 8888888b. 8888888 88888888888 .d88888b.  8888888b.  
   d88P  Y88b d88P  Y88b 888   Y88b       d88888 888   Y88b  888       888    d88P" "Y88b 888   Y88b 
   Y88b.      888    888 888    888      d88P888 888    888  888       888    888     888 888    888 
    "Y888b.   888        888   d88P     d88P 888 888   d88P  888       888    888     888 888   d88P 
       "Y88b. 888        8888888P"     d88P  888 8888888P"   888       888    888     888 8888888P"  
         "888 888    888 888 T88b     d88P   888 888         888       888    888     888 888 T88b   
   Y88b  d88P Y88b  d88P 888  T88b   d8888888888 888         888       888    Y88b. .d88P 888  T88b  
    "Y8888P"   "Y8888P"  888   T88b d88P     888 888       8888888     888     "Y88888P"  888   T88b 

                              === LOCAL PROXY ===
'@

$script:BannerCompact = @'
   +=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
   |   S C R A P I T O R   L O C A L   P R O X Y   |
   +=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
'@

$script:Skull = @'
                            ___________
                       .--'"  .  "'--. 
                      /  .   /_\   .  \
                     ;     .'   '.     ;
                     |    /       \    |
                     |   ;  O   O  ;   |
                     '.  |   ___   |  .'
                       '.|  |___|  |.'
                          '._____.
                            /   \
                           /     \
'@

# ── Spinner Frames ────────────────────────────────────────────────────────────
# Use ASCII-compatible spinner for maximum compatibility
$script:SpinnerFrames = @('|', '/', '-', '\')
$script:SpinnerIndex = 0
$script:SpinnerJob = $null

# Status icons - ASCII compatible
$script:Icons = @{
    Success  = '+'
    Error    = 'x'
    Warning  = '!'
    Info     = 'o'
    Pending  = '.'
    Arrow    = '>'
    Bullet   = '*'
}

# ── Functions ─────────────────────────────────────────────────────────────────

function Show-Banner {
    [CmdletBinding()]
    param(
        [switch]$Compact,
        [switch]$WithSkull,
        [switch]$Alt
    )
    
    try { Clear-Host } catch { }
    
    if ($WithSkull) {
        Write-Host $script:Skull -ForegroundColor $script:Theme.Muted
        Write-Host ""
    }
    
    $art = if ($Compact) { 
        $script:BannerCompact 
    } elseif ($Alt) {
        $script:BannerAlt
    } else { 
        $script:Banner 
    }
    Write-Host $art -ForegroundColor $script:Theme.Primary
    Write-Host ""
}

function Write-Status {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('Success', 'Error', 'Warning', 'Info', 'Pending')]
        [string]$Type = 'Info',
        [switch]$NoNewline
    )
    
    $icon = $script:Icons[$Type]
    $color = switch ($Type) {
        'Success' { $script:Theme.Success }
        'Error'   { $script:Theme.Error }
        'Warning' { $script:Theme.Warning }
        default   { $script:Theme.Muted }
    }
    
    $params = @{
        NoNewline = $NoNewline
    }
    
    Write-Host "  [" -NoNewline
    Write-Host $icon -ForegroundColor $color -NoNewline
    Write-Host "] " -NoNewline
    Write-Host $Message @params
}

function Write-Spinner {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Message
    )
    
    $frame = $script:SpinnerFrames[$script:SpinnerIndex]
    $script:SpinnerIndex = ($script:SpinnerIndex + 1) % $script:SpinnerFrames.Count
    
    Write-Host "`r  [$frame] $Message".PadRight(60) -NoNewline -ForegroundColor $script:Theme.Primary
}

function Clear-SpinnerLine {
    Write-Host "`r".PadRight(70) -NoNewline
    Write-Host "`r" -NoNewline
}

function Invoke-WithSpinner {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Message,
        [Parameter(Mandatory)][scriptblock]$Action,
        [string]$SuccessMessage,
        [string]$ErrorMessage,
        [int]$TimeoutSeconds = 0
    )
    
    $result = $null
    $error = $null
    $startTime = Get-Date
    
    # Run action in background
    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.Open()
    $ps = [powershell]::Create()
    $ps.Runspace = $runspace
    $null = $ps.AddScript($Action)
    $handle = $ps.BeginInvoke()
    
    try {
        # Animate spinner while waiting
        while (-not $handle.IsCompleted) {
            Write-Spinner -Message $Message
            Start-Sleep -Milliseconds 80
            
            if ($TimeoutSeconds -gt 0) {
                $elapsed = ((Get-Date) - $startTime).TotalSeconds
                if ($elapsed -gt $TimeoutSeconds) {
                    $ps.Stop()
                    throw "Operation timed out after $TimeoutSeconds seconds"
                }
            }
        }
        
        $result = $ps.EndInvoke($handle)
        if ($ps.HadErrors) {
            $error = $ps.Streams.Error | Select-Object -First 1
        }
    }
    catch {
        $error = $_
    }
    finally {
        $ps.Dispose()
        $runspace.Close()
    }
    
    Clear-SpinnerLine
    
    if ($error) {
        $msg = if ($ErrorMessage) { $ErrorMessage } else { $Message }
        Write-Status -Message $msg -Type Error
        throw $error
    }
    else {
        $msg = if ($SuccessMessage) { $SuccessMessage } else { $Message }
        Write-Status -Message $msg -Type Success
    }
    
    return $result
}

function Show-UrlBox {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$TunnelUrl,
        [Parameter(Mandatory)][int]$Port
    )
    
    $proxyUrl = "$TunnelUrl/openrouter-cc"
    $localUrl = "http://localhost:$Port"
    
    # Calculate box width
    $maxLen = [Math]::Max($proxyUrl.Length, $localUrl.Length)
    $boxWidth = $maxLen + 8
    
    $topBot = "=" * ($boxWidth - 2)
    $divider = "-" * ($boxWidth - 2)
    
    Write-Host ""
    Write-Host "  +$topBot+" -ForegroundColor $script:Theme.Primary
    Write-Host "  |" -ForegroundColor $script:Theme.Primary -NoNewline
    Write-Host " PROXY URL (paste into JanitorAI):".PadRight($boxWidth - 2) -NoNewline
    Write-Host "|" -ForegroundColor $script:Theme.Primary
    Write-Host "  |" -ForegroundColor $script:Theme.Primary -NoNewline
    Write-Host " $proxyUrl".PadRight($boxWidth - 2) -ForegroundColor $script:Theme.Success -NoNewline
    Write-Host "|" -ForegroundColor $script:Theme.Primary
    Write-Host "  +$divider+" -ForegroundColor $script:Theme.Primary
    Write-Host "  |" -ForegroundColor $script:Theme.Primary -NoNewline
    Write-Host " Dashboard: $localUrl".PadRight($boxWidth - 2) -ForegroundColor $script:Theme.Muted -NoNewline
    Write-Host "|" -ForegroundColor $script:Theme.Primary
    Write-Host "  +$topBot+" -ForegroundColor $script:Theme.Primary
    Write-Host ""
}

function Show-ErrorBox {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Title,
        [string[]]$Details,
        [int]$CountdownSeconds = 0
    )
    
    $boxWidth = 60
    $border = "=" * $boxWidth
    $divider = "-" * $boxWidth
    
    Write-Host ""
    Write-Host "  +$border+" -ForegroundColor $script:Theme.Error
    Write-Host "  |  $($script:Icons.Error) ERROR: $Title".PadRight($boxWidth + 1) + "|" -ForegroundColor $script:Theme.Error
    Write-Host "  +$divider+" -ForegroundColor $script:Theme.Error
    
    foreach ($line in $Details) {
        $padded = "  |  $line".PadRight($boxWidth + 1) + "|"
        Write-Host $padded -ForegroundColor $script:Theme.Warning
    }
    
    Write-Host "  +$border+" -ForegroundColor $script:Theme.Error
    Write-Host ""
    
    if ($CountdownSeconds -gt 0) {
        for ($i = $CountdownSeconds; $i -gt 0; $i--) {
            Write-Host "`r  Closing in $i seconds... (press any key to close now)" -NoNewline -ForegroundColor $script:Theme.Muted
            try {
                if ([Console]::KeyAvailable) {
                    $null = [Console]::ReadKey($true)
                    break
                }
            } catch { }
            Start-Sleep -Seconds 1
        }
        Write-Host ""
    }
}

function Show-QuickHelp {
    Write-Host ""
    Write-Host "  $($script:Icons.Bullet) " -ForegroundColor $script:Theme.Muted -NoNewline
    Write-Host "Press " -NoNewline
    Write-Host "Q" -ForegroundColor $script:Theme.Accent -NoNewline
    Write-Host " to quit  " -NoNewline
    Write-Host "$($script:Icons.Bullet) " -ForegroundColor $script:Theme.Muted -NoNewline
    Write-Host "Setup guide: " -NoNewline
    Write-Host "http://localhost:5000" -ForegroundColor $script:Theme.Primary
    Write-Host ""
}

function Test-InteractiveConsole {
    [CmdletBinding()]
    param()
    
    try {
        # Check if we have a real console
        $null = [Console]::WindowWidth
        return $true
    }
    catch {
        return $false
    }
}

function Wait-ForQuitKey {
    [CmdletBinding()]
    param(
        [scriptblock]$OnTick,
        [int]$TickIntervalMs = 1000
    )
    
    $isInteractive = Test-InteractiveConsole
    $lastTick = Get-Date
    
    while ($true) {
        # Only check for keypress if we have an interactive console
        if ($isInteractive) {
            try {
                if ([Console]::KeyAvailable) {
                    $key = [Console]::ReadKey($true)
                    if ($key.Key -eq 'Q' -or $key.Key -eq 'Escape') {
                        return 'quit'
                    }
                }
            }
            catch {
                # Console became unavailable, switch to non-interactive mode
                $isInteractive = $false
            }
        }
        
        if ($OnTick -and ((Get-Date) - $lastTick).TotalMilliseconds -ge $TickIntervalMs) {
            $result = & $OnTick
            if ($result -eq 'exit') { return 'exit' }
            $lastTick = Get-Date
        }
        
        Start-Sleep -Milliseconds 100
    }
}

function Write-Subtle {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Message
    )
    Write-Host "  $Message" -ForegroundColor $script:Theme.Muted
}

function Write-Section {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Title
    )
    Write-Host ""
    Write-Host "  -- $Title " -ForegroundColor $script:Theme.Primary -NoNewline
    Write-Host ("-" * (50 - $Title.Length)) -ForegroundColor $script:Theme.Muted
    Write-Host ""
}

# ── Export ────────────────────────────────────────────────────────────────────
Export-ModuleMember -Function @(
    'Show-Banner',
    'Write-Status',
    'Write-Spinner',
    'Clear-SpinnerLine',
    'Invoke-WithSpinner',
    'Show-UrlBox',
    'Show-ErrorBox',
    'Show-QuickHelp',
    'Wait-ForQuitKey',
    'Test-InteractiveConsole',
    'Write-Subtle',
    'Write-Section'
)

