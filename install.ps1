# VibePerks Terminal installer (Windows, PowerShell).
#
# Builds the adapter binary and adds a managed block to your PowerShell profile that
# dot-sources the VibePerks Terminal shell integration. Re-running is safe: the managed
# block is replaced, not duplicated.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$begin = '# >>> vibeperks-terminal >>>'
$end = '# <<< vibeperks-terminal <<<'

# Resolve a runnable binary without requiring Go:
#   1) a prebuilt distribution binary shipped in bin/ (bin\vibeperks-terminal-windows-amd64.exe)
#   2) a prebuilt binary downloaded from the GitHub Release (no Go toolchain needed)
#   3) build from src/ when the Go toolchain is available
$prebuilt = Join-Path $root 'bin\vibeperks-terminal-windows-amd64.exe'
$bin = Join-Path $root 'bin\vibeperks-terminal.exe'

if (Test-Path -LiteralPath $prebuilt) {
    Write-Host 'Using prebuilt adapter binary (no Go toolchain needed).'
    Copy-Item -LiteralPath $prebuilt -Destination $bin -Force
} else {
    # Download the prebuilt binary from the GitHub Release. Channel defaults to the
    # moving "latest" release; set VIBEPERKS_RELEASE_CHANNEL=dev-latest for the dev prerelease.
    $channel = if ($env:VIBEPERKS_RELEASE_CHANNEL) { $env:VIBEPERKS_RELEASE_CHANNEL } else { 'latest' }
    $url = if ($channel -eq 'latest') {
        'https://github.com/VibePerks/terminal/releases/latest/download/vibeperks-terminal-windows-amd64.exe'
    } else {
        "https://github.com/VibePerks/terminal/releases/download/$channel/vibeperks-terminal-windows-amd64.exe"
    }
    $downloaded = $false
    try {
        Write-Host "Downloading the prebuilt adapter binary ($channel)..."
        Invoke-WebRequest -UseBasicParsing $url -OutFile $bin
        $downloaded = (Test-Path -LiteralPath $bin)
    } catch {
        $downloaded = $false
    }
    if (-not $downloaded) {
        if (Get-Command go -ErrorAction SilentlyContinue) {
            Write-Host 'Download unavailable; building the adapter binary...'
            & go build -C (Join-Path $root 'src') -trimpath -o $bin .
        } else {
            Write-Error 'Could not download a prebuilt binary and Go is not installed. Install Go (https://go.dev/dl) and re-run, or check your network and retry.'
        }
    }
}
$integration = Join-Path $root 'scripts\shell-integration.ps1'
$block = @"
$begin
`$env:VIBEPERKS_TERMINAL_BIN = '$bin'
. '$integration'
$end
"@

$profilePath = $PROFILE.CurrentUserAllHosts
New-Item -ItemType File -Path $profilePath -Force | Out-Null
$content = Get-Content -LiteralPath $profilePath -Raw -ErrorAction SilentlyContinue
if ($null -eq $content) { $content = '' }
# Remove any previous managed block, then append the current one.
$pattern = [regex]::Escape($begin) + '.*?' + [regex]::Escape($end)
$content = [regex]::Replace($content, $pattern, '', 'Singleline').TrimEnd()
Set-Content -LiteralPath $profilePath -Value ($content + "`n" + $block + "`n")

# Detect an existing, already-configured device token so re-installs don't nag the user
# to log in again. Mirrors core.ConfigDir(): $VIBEPERKS_HOME overrides ~/.vibeperks.
$configDir = if ($env:VIBEPERKS_HOME) { $env:VIBEPERKS_HOME } else { Join-Path $HOME '.vibeperks' }
$configPath = Join-Path $configDir 'config.json'
$hasToken = $false
if (Test-Path -LiteralPath $configPath) {
    try {
        $cfg = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
        if ($cfg.device_token -and $cfg.device_token.Trim()) { $hasToken = $true }
    } catch {
        # Malformed config: treat as not configured and fall through to the login hint.
    }
}

if ($hasToken) {
    Write-Host 'Installed. Existing device token detected - no login needed. Open a new PowerShell to start.'
} else {
    Write-Host 'Installed. Open a new PowerShell, then run: vibeperks-terminal login <device-token>'
}
