# build.ps1 — Stage 1 mechanical crawler
# Reads build/config.yaml for source root; walks it for SKILL.md-bearing folders;
# mirrors folder structure to skills/ applying deny list.
# Stage 2 reference resolver (T4) will prune further. Stage 1 copies all files.
#
# Usage: pwsh build/build.ps1 [--dry-run]
# Run from the plugin repo root.

[CmdletBinding()]
param(
    [switch]$DryRun,
    # Optional: override source path from config (useful when running from a nested worktree)
    [string]$SourcePath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Repo root is the parent of the build/ dir (where this script lives)
$RepoRoot   = $PSScriptRoot | Split-Path -Parent
$ConfigFile = Join-Path $PSScriptRoot 'config.yaml'

# ---------------------------------------------------------------------------
# Parse config.yaml (simple line-by-line; no external YAML module required)
# ---------------------------------------------------------------------------
function Read-Config {
    param([string]$Path)
    $cfg = @{ source = @{}; output = './skills'; 'deny-extra' = @() }
    $section = $null
    foreach ($line in (Get-Content $Path)) {
        $trimmed = $line.TrimEnd()
        if ($trimmed -match '^\s*#') { continue }   # comment
        if ($trimmed -match '^source:') { $section = 'source'; continue }
        if ($trimmed -match '^output:\s*(.+)') { $cfg.output = $Matches[1].Trim("' `""); continue }
        if ($trimmed -match '^\s+mode:\s*([^#]+)') { $cfg.source.mode = $Matches[1].Trim("' `""); continue }
        if ($trimmed -match '^\s+path:\s*([^#]+)') { $cfg.source.path = $Matches[1].Trim("' `""); continue }
        # deny-extra: [] or deny-extra: [item, item]  (simplified — inline list only for now)
        if ($trimmed -match '^deny-extra:\s*\[([^\]]*)\]') {
            $items = $Matches[1] -split ',' | ForEach-Object { $_.Trim().Trim("'`"") } | Where-Object { $_ }
            $cfg['deny-extra'] = @($items)
        }
    }
    return $cfg
}

$config = Read-Config -Path $ConfigFile

# ---------------------------------------------------------------------------
# Resolve source root
# ---------------------------------------------------------------------------
if ($config.source.mode -ne 'sibling') {
    Write-Error "Only 'sibling' mode is supported in Stage 1 (T13 adds url mode). Got: $($config.source.mode)"
    exit 1
}

$resolvedSourcePath = if ($SourcePath) { $SourcePath } else { $config.source.path }
$SourceRoot = if ([System.IO.Path]::IsPathRooted($resolvedSourcePath)) {
    (Resolve-Path $resolvedSourcePath).Path
} else {
    (Resolve-Path (Join-Path $RepoRoot $resolvedSourcePath)).Path
}
$OutputRoot = (Join-Path $RepoRoot $config.output.TrimStart('.').TrimStart('/').TrimStart('\'))
if (-not (Test-Path $SourceRoot)) {
    Write-Error "Source root not found: $SourceRoot"
    exit 1
}

# ---------------------------------------------------------------------------
# Deny list (operator-locked)
# ---------------------------------------------------------------------------
$DenyFiles = [System.Collections.Generic.HashSet[string]]([System.StringComparer]::OrdinalIgnoreCase)
@(
    'spec.md'
    'uncompressed.md'
    'instructions.uncompressed.md'
    'instructions.uncompressed.md.compressed'
    'optimize-log.md'
    'eval.md'
    'PLAN.md'
    'RESULTS.md'
) | ForEach-Object { [void]$DenyFiles.Add($_) }

# Wildcard patterns (evaluated per file)
$DenyPatterns = @('*.spec.md', '*.sha256')

# Workspace-level extras from config
foreach ($extra in $config['deny-extra']) {
    if ($extra) { [void]$DenyFiles.Add($extra) }
}

function Test-Denied {
    param([System.IO.FileInfo]$File)
    if ($DenyFiles.Contains($File.Name)) { return $true }
    foreach ($pat in $DenyPatterns) {
        if ($File.Name -like $pat) { return $true }
    }
    return $false
}

function Test-DotDir {
    param([System.IO.DirectoryInfo]$Dir)
    return $Dir.Name.StartsWith('.')
}

# ---------------------------------------------------------------------------
# Crawl: find all SKILL.md-bearing folders recursively
# ---------------------------------------------------------------------------
$SkillFolders = [System.Collections.Generic.List[System.IO.DirectoryInfo]]::new()

Get-ChildItem -Path $SourceRoot -Recurse -Directory | ForEach-Object {
    $dir = $_
    # Skip dot-dirs themselves
    if (Test-DotDir $dir) { return }
    # Skip if any ancestor component is a dot-dir
    $relPath = $dir.FullName.Substring($SourceRoot.Length).TrimStart([IO.Path]::DirectorySeparatorChar, '/')
    $parts = $relPath -split '[/\\]'
    if ($parts | Where-Object { $_.StartsWith('.') }) { return }

    if (Test-Path (Join-Path $dir.FullName 'SKILL.md')) {
        $SkillFolders.Add($dir)
    }
}

Write-Host "[build] Source root : $SourceRoot"
Write-Host "[build] Output root : $OutputRoot"
Write-Host "[build] Skill folders found: $($SkillFolders.Count)"
Write-Host ""

# ---------------------------------------------------------------------------
# Mirror each skill folder to output
# ---------------------------------------------------------------------------
$totalCopied = 0
$totalDenied = 0

foreach ($skillDir in $SkillFolders) {
    $relPath = $skillDir.FullName.Substring($SourceRoot.Length).TrimStart([IO.Path]::DirectorySeparatorChar, '/')
    $destDir = Join-Path $OutputRoot $relPath

    if (-not $DryRun) {
        New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    }

    # Copy direct files (non-recursive — subdirs handled by their own skill folder iteration)
    Get-ChildItem -Path $skillDir.FullName -File | ForEach-Object {
        $file = $_
        if (Test-Denied $file) {
            $totalDenied++
            return
        }
        $destFile = Join-Path $destDir $file.Name
        if (-not $DryRun) {
            Copy-Item -Path $file.FullName -Destination $destFile -Force
        }
        $totalCopied++
    }
}

# ---------------------------------------------------------------------------
# Build report
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[build] ── Stage 1 Report ──────────────────────────"
Write-Host "[build]   SKILL.md folders : $($SkillFolders.Count)"
Write-Host "[build]   Files copied     : $totalCopied"
Write-Host "[build]   Files denied     : $totalDenied"
if ($DryRun) { Write-Host "[build]   (DRY RUN — no files written)" }
Write-Host "[build] ─────────────────────────────────────────────"

