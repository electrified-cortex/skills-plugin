#!/usr/bin/env pwsh
#Requires -Version 7
# misses.ps1 — parallel batch cache-miss probe across a glob of files
# Usage: misses.ps1 <glob> <op_kind> <record_filename>
# Output: one absolute file path per line for each file with no cache entry (MISS)
# Exit: 0 success (including zero matches); 1 argument or runtime error
# Deps: pwsh 7.0+, git on PATH.
# Notes: ignores any matched path under .hash-record/ to avoid cache self-scans.

param(
    [Parameter(Position = 0, Mandatory)]
    [string]$Glob,

    [Parameter(Position = 1, Mandatory)]
    [string]$OpKind,

    [Parameter(Position = 2, Mandatory)]
    [string]$RecordFilename
)

$ErrorActionPreference = 'Stop'

# Validate
if ($OpKind -match '\.\.' -or $OpKind -match '[\\]') {
    [Console]::Error.WriteLine("ERROR: invalid op_kind: $OpKind")
    exit 1
}
if ($RecordFilename -match '\.\.' -or $RecordFilename -match '[/\\]') {
    [Console]::Error.WriteLine("ERROR: invalid record_filename: $RecordFilename")
    exit 1
}

# Expand glob — PowerShell does not support ** natively in -Path;
# handle recursive (**) and flat (*) globs explicitly.
$files = if ($Glob -match '\*\*') {
    # Split at **  e.g. "path/to/**/*.md"  -> base="path/to", leaf="*.md"
    $basePart = ($Glob -replace '[\\/]?\*\*.*$', '').Trim()
    if (-not $basePart) { $basePart = '.' }
    $leafPart = if ($Glob -match '\*\*[\\/](.+)$') { $Matches[1] } else { '*' }
    Get-ChildItem -Path $basePart -Recurse -Filter $leafPart -File -ErrorAction SilentlyContinue
} else {
    Get-ChildItem -Path $Glob -File -ErrorAction SilentlyContinue
}
if (-not $files -or $files.Count -eq 0) { exit 0 }

# Never process files inside the cache tree itself.
$files = $files | Where-Object {
    $_.FullName -notmatch '[/\\]\.hash-record[/\\]'
}
if (-not $files -or $files.Count -eq 0) { exit 0 }

# Resolve repo root from the first matched file
$firstDir = Split-Path -Parent $files[0].FullName
$repoRoot = (& git -C $firstDir rev-parse --show-toplevel 2>$null)
if (-not $repoRoot) {
    [Console]::Error.WriteLine("WARN: not in a git repo; falling back to file's parent dir as repo_root: $firstDir")
    $repoRoot = $firstDir
}
$repoRoot = $repoRoot.Trim().TrimEnd('/', '\').Replace('\', '/')

# Parallel probe — output file path for every MISS, sorted for deterministic order
$files | ForEach-Object -Parallel {
    $f = $_.FullName
    $hash = (& git hash-object $f 2>$null)
    if ($LASTEXITCODE -ne 0 -or -not $hash) { return }
    $hash = $hash.Trim()
    $shard = $hash.Substring(0, 2)
    $cachePath = "$($using:repoRoot)/.hash-record/$shard/$hash/$($using:OpKind)/$($using:RecordFilename)"
    if (-not (Test-Path -LiteralPath $cachePath -PathType Leaf)) {
        $f
    }
} -ThrottleLimit 16 | Sort-Object
