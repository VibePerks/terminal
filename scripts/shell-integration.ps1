# VibePerks Terminal - shell integration (PowerShell).
#
# Dot-source this from your PowerShell profile. It renders the cached VibePerks sponsor line
# above each prompt and, when PSReadLine is available, rebinds Enter so pressing it on a real
# command launches a background refresh. Rendering makes ZERO network calls - it only reads
# the local cache via `vibeperks-terminal render`.
#
# Set $env:VIBEPERKS_TERMINAL_BIN to the binary path if it is not on PATH.

function Get-VibeperksTerminalBin {
    if ($env:VIBEPERKS_TERMINAL_BIN) { return $env:VIBEPERKS_TERMINAL_BIN }
    return 'vibeperks-terminal'
}

function Show-VibeperksTerminalLine {
    if ($env:VIBEPERKS_TERMINAL_PROMPT_LINE -eq '0') { return }
    $bin = Get-VibeperksTerminalBin
    if (-not (Get-Command $bin -ErrorAction SilentlyContinue)) { return }
    $line = (& $bin render 2>$null | Out-String).Trim()
    if (-not $line) { return }
    Write-Host $line
}

function Test-VibeperksTerminalShouldRefresh {
    param([AllowNull()][string] $CommandText)
    if ([string]::IsNullOrWhiteSpace($CommandText)) { return $false }
    $trimmed = $CommandText.TrimStart()
    if ($trimmed.StartsWith('#')) { return $false }
    $first = ($trimmed -split '\s+', 2)[0].Trim('"', "'")
    $name = Split-Path -Leaf $first
    return @('vibeperks-terminal', 'vibeperks-terminal.exe') -notcontains $name
}

function Invoke-VibeperksTerminalRefresh {
    param([string] $CommandText)
    if ($env:VIBEPERKS_TERMINAL_ENTER -eq '0') { return }
    if (-not (Test-VibeperksTerminalShouldRefresh $CommandText)) { return }
    $bin = Get-VibeperksTerminalBin
    if (-not (Get-Command $bin -ErrorAction SilentlyContinue)) { return }
    try {
        Start-Job -ArgumentList $bin -ScriptBlock {
            param([string] $Bin)
            try { & $Bin refresh $PID *> $null } catch {}
        } | Out-Null
    } catch {}
}

# Render line: wrap the existing prompt function so we run before it.
if (-not (Test-Path Function:\__VibeperksTerminalOrigPrompt)) {
    Copy-Item Function:\prompt Function:\__VibeperksTerminalOrigPrompt -ErrorAction SilentlyContinue
}
function prompt {
    Show-VibeperksTerminalLine
    if (Test-Path Function:\__VibeperksTerminalOrigPrompt) { & __VibeperksTerminalOrigPrompt }
    else { "PS $($executionContext.SessionState.Path.CurrentLocation)> " }
}

# Enter trigger via PSReadLine (optional - rendering works without it).
if ($env:VIBEPERKS_TERMINAL_ENTER -ne '0' -and (Get-Command Set-PSReadLineKeyHandler -ErrorAction SilentlyContinue)) {
    Set-PSReadLineKeyHandler -Key Enter -ScriptBlock {
        $line = $null
        $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
        Invoke-VibeperksTerminalRefresh $line
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }
}
