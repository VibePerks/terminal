# VibePerks Terminal uninstaller (Windows, PowerShell).
#
# Removes the managed block that install.ps1 added to your PowerShell profile, so the
# sponsor line and Enter hook stop loading in new sessions. Your local config/cache in
# ~/.vibeperks is left untouched; delete that directory yourself if you also want to
# remove your device token and cached ad.
$ErrorActionPreference = 'Stop'
$begin = '# >>> vibeperks-terminal >>>'
$end = '# <<< vibeperks-terminal <<<'

$profilePath = $PROFILE.CurrentUserAllHosts
if (-not (Test-Path -LiteralPath $profilePath)) {
    Write-Host 'Nothing to remove: no PowerShell profile found.'
    return
}

$content = Get-Content -LiteralPath $profilePath -Raw -ErrorAction SilentlyContinue
if ($null -eq $content -or -not $content.Contains($begin)) {
    Write-Host 'Nothing to remove: no VibePerks block in your profile.'
    return
}

$pattern = [regex]::Escape($begin) + '.*?' + [regex]::Escape($end)
$content = [regex]::Replace($content, $pattern, '', 'Singleline').TrimEnd()
Set-Content -LiteralPath $profilePath -Value ($content + "`n")

Write-Host 'Uninstalled. Open a new PowerShell to apply. Delete ~/.vibeperks to also remove your token and cache.'
