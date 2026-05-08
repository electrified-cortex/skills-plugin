#Requires -Version 7
# plan.ps1 — Compute the deterministic dist manifest for skills-plugin.
#
# Usage:
#   plan.ps1 [--source <path>] [--check] [--save]
#
# --source <path>  Override source root (default: sibling ../electrified-cortex/skills)
# --check          Compare computed manifest against .hash-record/publish/last-manifest.txt
#                  Exit 0 = changes found (publish needed)
#                  Exit 1 = no changes (nothing to publish)
# --save           Write computed manifest to .hash-record/publish/last-manifest.txt
#
# Without --check or --save: prints manifest to stdout, exits 0.
#
# Manifest format (one line per file, sorted by relative path):
#   skills/<rel-path>: <git-blob-hash>

param(
    [string]$Source,
    [switch]$Check,
    [switch]$Save
)

$ErrorActionPreference = 'Stop'

$pluginRoot = Split-Path -Parent $PSScriptRoot

# ── Source root ──────────────────────────────────────────────────────────────
if (-not $Source) {
    $Source = Join-Path $pluginRoot '..\skills'
}
$sourceRoot = (Resolve-Path $Source).Path
if (-not (Test-Path $sourceRoot)) {
    Write-Error "Source root not found: $sourceRoot"
    exit 2
}

# ── Dot-source deny list ─────────────────────────────────────────────────────
. (Join-Path $pluginRoot 'build\deny-list.ps1')

# ── Hash helper (LF-normalized, same as manifest.ps1) ────────────────────────
function Get-BlobHash([string]$FilePath) {
    $bytes = [System.IO.File]::ReadAllBytes($FilePath)
    $out   = [System.Collections.Generic.List[byte]]::new($bytes.Length)
    $i = 0
    while ($i -lt $bytes.Length) {
        if ($bytes[$i] -eq 13) {
            $out.Add(10)
            if ($i + 1 -lt $bytes.Length -and $bytes[$i + 1] -eq 10) { $i++ }
        } else {
            $out.Add($bytes[$i])
        }
        $i++
    }
    $tmp = [System.IO.Path]::GetTempFileName()
    try {
        [System.IO.File]::WriteAllBytes($tmp, $out.ToArray())
        $h = (& git hash-object $tmp 2>$null)
        if ($LASTEXITCODE -ne 0 -or -not $h) { return $null }
        return $h.Trim()
    } finally {
        Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue
    }
}

# ── Ancestor dot-dir check ────────────────────────────────────────────────────
function Test-DotAncestor([string]$fullPath, [string]$rootPath) {
    $rel = $fullPath.Substring($rootPath.Length).TrimStart('\/')
    foreach ($seg in ($rel -split '[\/\\]')) {
        if ($seg.StartsWith('.')) { return $true }
    }
    return $false
}

# ── Discover skill folders ────────────────────────────────────────────────────
$skillFolders = Get-ChildItem -Path $sourceRoot -Recurse -Filter 'SKILL.md' |
    Where-Object { -not (Test-DotAncestor $_.Directory.FullName $sourceRoot) } |
    Select-Object -ExpandProperty Directory |
    Sort-Object FullName

# ── Build manifest entries ────────────────────────────────────────────────────
$entries = [System.Collections.Generic.SortedDictionary[string,string]]::new([System.StringComparer]::Ordinal)

foreach ($dir in $skillFolders) {
    $relDir = $dir.FullName.Substring($sourceRoot.Length).TrimStart('\/')
    Get-ChildItem -Path $dir.FullName -File | ForEach-Object {
        if (-not (Test-Denied $_) -and -not (Test-DotFile $_)) {
            $hash = Get-BlobHash $_.FullName
            if ($hash) {
                $key = "skills/$($relDir.Replace('\','/'))" + "/$($_.Name)"
                $entries[$key] = $hash
            }
        }
    }
}

# ── Index files (skill.index, skill.index.md at source root) ─────────────────
foreach ($idxName in @('skill.index', 'skill.index.md')) {
    $idxPath = Join-Path $sourceRoot $idxName
    if (Test-Path $idxPath) {
        $hash = Get-BlobHash $idxPath
        if ($hash) { $entries["skills/$idxName"] = $hash }
    }
}

# ── Render manifest ───────────────────────────────────────────────────────────
$lines = $entries.GetEnumerator() | ForEach-Object { "$($_.Key): $($_.Value)" }
$manifest = $lines -join "`n"

Write-Output $manifest

# ── --save: write to hash-record ─────────────────────────────────────────────
if ($Save) {
    $recordDir = Join-Path $pluginRoot '.hash-record\publish'
    New-Item -ItemType Directory -Path $recordDir -Force | Out-Null
    $recordPath = Join-Path $recordDir 'last-manifest.txt'
    [System.IO.File]::WriteAllText($recordPath, $manifest + "`n")
    Write-Host "Saved manifest -> $recordPath"
}

# ── --check: diff against stored manifest ────────────────────────────────────
if ($Check) {
    $recordPath = Join-Path $pluginRoot '.hash-record\publish\last-manifest.txt'
    if (-not (Test-Path $recordPath)) {
        Write-Host "No stored manifest found at $recordPath — first publish."
        exit 0
    }

    $stored = Get-Content $recordPath -Raw
    $storedMap = [System.Collections.Generic.Dictionary[string,string]]::new([System.StringComparer]::Ordinal)
    foreach ($line in ($stored -split "`n" | Where-Object { $_ -match ':' })) {
        $parts = $line -split ': ', 2
        if ($parts.Count -eq 2) { $storedMap[$parts[0]] = $parts[1] }
    }

    $newMap = $entries

    $added   = $newMap.Keys | Where-Object { -not $storedMap.ContainsKey($_) }
    $removed = $storedMap.Keys | Where-Object { -not $newMap.ContainsKey($_) }
    $changed = $newMap.Keys | Where-Object { $storedMap.ContainsKey($_) -and $storedMap[$_] -ne $newMap[$_] }

    $totalChanges = @($added).Count + @($removed).Count + @($changed).Count

    if ($totalChanges -eq 0) {
        Write-Host "No changes since last publish — nothing to publish."
        exit 1
    }

    Write-Host "Changes since last publish: $($totalChanges) file(s)"
    if (@($added).Count   -gt 0) { Write-Host "  Added   ($(@($added).Count)):   $($added   -join ', ')" }
    if (@($removed).Count -gt 0) { Write-Host "  Removed ($(@($removed).Count)): $($removed -join ', ')" }
    if (@($changed).Count -gt 0) { Write-Host "  Changed ($(@($changed).Count)): $($changed -join ', ')" }
    exit 0
}
