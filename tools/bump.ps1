#Requires -Version 7
# bump.ps1 — Bump the plugin.json version and optionally create an annotated git tag.
#
# Usage:
#   bump.ps1 [patch|minor|major] [--tag] [--dry-run]
#
# patch    Increment patch, reset nothing.  0.1.8 -> 0.1.9
# minor    Increment minor, reset patch.    0.1.8 -> 0.2.0
# major    Increment major, reset minor+patch. 0.1.8 -> 1.0.0
#
# --tag      Create annotated git tag v<new-version> after writing plugin.json.
# --dry-run  Print new version only; no writes, no tag.

param(
    [Parameter(Position=0)]
    [ValidateSet('patch','minor','major')]
    [string]$Bump = 'patch',

    [switch]$Tag,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$pluginRoot  = Split-Path -Parent $PSScriptRoot
$pluginJson  = Join-Path $pluginRoot 'plugin.json'

if (-not (Test-Path $pluginJson)) {
    Write-Error "plugin.json not found: $pluginJson"
    exit 1
}

# ── Read current version ──────────────────────────────────────────────────────
$json = Get-Content $pluginJson -Raw | ConvertFrom-Json
$current = $json.version

if ($current -notmatch '^(\d+)\.(\d+)\.(\d+)$') {
    Write-Error "plugin.json version is not valid SemVer: $current"
    exit 1
}

[int]$major = $Matches[1]
[int]$minor = $Matches[2]
[int]$patch = $Matches[3]

# ── Compute new version ───────────────────────────────────────────────────────
switch ($Bump) {
    'patch' { $patch++ }
    'minor' { $minor++; $patch = 0 }
    'major' { $major++; $minor = 0; $patch = 0 }
}

$newVersion = "$major.$minor.$patch"
Write-Host "$current -> $newVersion"

if ($DryRun) {
    Write-Host "[dry-run] No changes written."
    exit 0
}

# ── Write plugin.json ─────────────────────────────────────────────────────────
$json.version = $newVersion
$json.built   = (Get-Date -Format 'yyyy-MM-dd')
$jsonOut = $json | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($pluginJson, $jsonOut + "`n")
Write-Host "Wrote $pluginJson"

# ── Tag ───────────────────────────────────────────────────────────────────────
if ($Tag) {
    Push-Location $pluginRoot
    try {
        & git tag -a "v$newVersion" -m "v$newVersion"
        if ($LASTEXITCODE -ne 0) {
            Write-Error "git tag failed (exit $LASTEXITCODE)"
            exit 1
        }
        Write-Host "Tagged v$newVersion"
    } finally {
        Pop-Location
    }
}
