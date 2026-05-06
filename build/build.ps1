# build.ps1 — Stage 1 mechanical crawler + Stage 2 reference resolver
# Stage 1: reads build/config.yaml for source root; walks it for SKILL.md-bearing
#          folders; mirrors folder structure to skills/ applying deny list.
# Stage 2: parses SKILL.md (and transitively referenced files) for backtick file
#          references; copies any missing referenced files into the dist output.
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
# Deny list (loaded from shared module)
# ---------------------------------------------------------------------------
. (Join-Path $PSScriptRoot 'deny-list.ps1')

# ---------------------------------------------------------------------------
# Stage 2 — Reference resolver helper
# ---------------------------------------------------------------------------
function Resolve-SkillRefs {
    param(
        [string]$SourceSkillDir,   # absolute path to skill in source
        [string]$DestSkillDir,     # absolute path to skill in dist
        [string]$FilePath,         # file to parse (absolute path)
        [int]$Depth = 0,
        [hashtable]$Visited = $null
    )

    if ($null -eq $Visited) { $Visited = @{} }
    if ($Depth -gt 4) { return @() }
    if (-not (Test-Path -LiteralPath $FilePath)) { return @() }

    # Prevent exponential re-traversal of the same source file
    if ($Visited.ContainsKey($FilePath)) { return @() }
    $Visited[$FilePath] = $true

    $content = Get-Content $FilePath -Raw -ErrorAction SilentlyContinue
    if (-not $content) { return @() }

    $resolved = [System.Collections.Generic.List[string]]::new()

    # Pattern: backtick-wrapped paths with file extensions (skip pure code/model names)
    $backtickRefs = [regex]::Matches($content, '`([^`\n]+\.[a-zA-Z]{2,6})`')
    foreach ($match in $backtickRefs) {
        $ref = $match.Groups[1].Value.Trim()

        # Skip wildcard deny patterns (e.g., `*.spec.md`)
        if ($ref -match '^\*\.') { continue }

        # Skip cross-skill refs (../other/) — warn but don't follow
        if ($ref -match '^\.\./') {
            Write-Host "[build] Stage 2: cross-skill ref (skipped): $ref in $FilePath" -ForegroundColor Yellow
            continue
        }

        # Template path: `<var>/file.ext` — expand to all matching files in source skill tree
        if ($ref -match '<[^>]+>') {
            $leafName = ($ref -split '[/\\]')[-1]
            $expandedFiles = Get-ChildItem -Path $SourceSkillDir -Recurse -File -Filter $leafName -ErrorAction SilentlyContinue
            foreach ($expanded in $expandedFiles) {
                if (Test-Denied $expanded) { continue }
                if (Test-DotFile $expanded) { continue }
                $relFromSkill = $expanded.FullName.Substring($SourceSkillDir.Length).TrimStart([IO.Path]::DirectorySeparatorChar, '/')
                $destFile = Join-Path $DestSkillDir $relFromSkill
                # Always recurse for transitive refs; only copy if not already in dest
                Resolve-SkillRefs -SourceSkillDir $SourceSkillDir -DestSkillDir $DestSkillDir -FilePath $expanded.FullName -Depth ($Depth + 1) -Visited $Visited | ForEach-Object { [void]$resolved.Add($_) }
                if (-not (Test-Path -LiteralPath $destFile)) {
                    $destSubDir = Split-Path $destFile -Parent
                    New-Item -ItemType Directory -Force -Path $destSubDir | Out-Null
                    Copy-Item -LiteralPath $expanded.FullName -Destination $destFile -Force
                    [void]$resolved.Add($destFile)
                }
            }
            continue
        }

        # Direct path: resolve relative to the file's directory
        $fileDir = Split-Path $FilePath -Parent
        $absRef = Join-Path $fileDir $ref
        $absRef = [System.IO.Path]::GetFullPath($absRef)

        # Must be inside the source skill tree
        if (-not $absRef.StartsWith($SourceSkillDir)) { continue }
        if (-not (Test-Path -LiteralPath $absRef)) { continue }

        $refInfo = Get-Item -LiteralPath $absRef
        if ($refInfo -isnot [System.IO.FileInfo]) { continue }
        if (Test-Denied $refInfo) { continue }
        if (Test-DotFile $refInfo) { continue }

        $relFromSkill = $absRef.Substring($SourceSkillDir.Length).TrimStart([IO.Path]::DirectorySeparatorChar, '/')
        $destFile = Join-Path $DestSkillDir $relFromSkill

        # Always recurse for transitive refs; only copy if not already in dest
        Resolve-SkillRefs -SourceSkillDir $SourceSkillDir -DestSkillDir $DestSkillDir -FilePath $absRef -Depth ($Depth + 1) -Visited $Visited | ForEach-Object { [void]$resolved.Add($_) }
        if (-not (Test-Path -LiteralPath $destFile)) {
            $destSubDir = Split-Path $destFile -Parent
            New-Item -ItemType Directory -Force -Path $destSubDir | Out-Null
            Copy-Item -LiteralPath $absRef -Destination $destFile -Force
            [void]$resolved.Add($destFile)
        }
    }

    return $resolved.ToArray()
}

# Workspace-level extras from config (add to shared deny set)
foreach ($extra in $config['deny-extra']) {
    if ($extra) { [void]$DenyFiles.Add($extra) }
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
        if (Test-DotFile $file) { $totalDenied++; return }
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
# Stage 2 — Reference resolver
# ---------------------------------------------------------------------------
$stage2Copied = 0
$stage2Warnings = [System.Collections.Generic.List[string]]::new()

foreach ($skillDir in $SkillFolders) {
    $relPath = $skillDir.FullName.Substring($SourceRoot.Length).TrimStart([IO.Path]::DirectorySeparatorChar, '/')
    $destDir = Join-Path $OutputRoot $relPath

    $skillMd = Join-Path $skillDir.FullName 'SKILL.md'
    if (-not (Test-Path $skillMd)) { continue }

    if (-not $DryRun) {
        $newFiles = @(Resolve-SkillRefs -SourceSkillDir $skillDir.FullName -DestSkillDir $destDir -FilePath $skillMd -Depth 0)
        $stage2Copied += $newFiles.Count
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
Write-Host "[build] ── Stage 2 Report ──────────────────────────"
Write-Host "[build]   Transitively resolved : $stage2Copied"
if ($stage2Warnings.Count -gt 0) {
    Write-Host "[build]   Warnings: $($stage2Warnings.Count)" -ForegroundColor Yellow
    foreach ($w in $stage2Warnings) { Write-Host "[build]     $w" -ForegroundColor Yellow }
}
if ($DryRun) { Write-Host "[build]   (DRY RUN — no files written)" }
Write-Host "[build] ─────────────────────────────────────────────"

# ---------------------------------------------------------------------------
# Post-copy dist validation (AC4 — error on any denied file in output)
# ---------------------------------------------------------------------------
if (-not $DryRun) {
    $distViolations = [System.Collections.Generic.List[string]]::new()
    Get-ChildItem -Path $OutputRoot -Recurse -File | ForEach-Object {
        $file = $_
        if (Test-Denied $file) {
            $distViolations.Add($file.FullName)
        }
        if (Test-DotFile $file) {
            $distViolations.Add($file.FullName)
        }
    }
    if ($distViolations.Count -gt 0) {
        Write-Host ""
        Write-Host "[build] ERROR: deny-pattern files found in dist output:" -ForegroundColor Red
        foreach ($v in $distViolations) {
            Write-Host "  $v" -ForegroundColor Red
        }
        exit 1
    }
}

