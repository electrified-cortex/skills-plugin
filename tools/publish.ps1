#Requires -Version 7
# publish.ps1 — Cut a new release of skills-plugin.
#
# Usage:
#   publish.ps1 -Bump <patch|minor|major> -Notes "<release notes>" [-Source <path>] [-DryRun] [-Force]
#
# -Bump      Required. SemVer increment: patch, minor, or major.
# -Notes     Required. Release notes for CHANGELOG entry.
# -Source    Override source root (default: sibling ../skills).
# -DryRun    All steps except commit/tag/push. Prints what would happen.
# -Force     Skip no-changes guard (re-publish identical content).

param(
    [Parameter(Mandatory)]
    [ValidateSet('patch','minor','major')]
    [string]$Bump,

    [Parameter(Mandatory)]
    [string]$Notes,

    [string]$Source,

    [switch]$DryRun,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$pluginRoot   = Split-Path -Parent $PSScriptRoot
# Canonical version source: .claude-plugin/plugin.json — the manifest Claude
# Code reads when the plugin is installed. There is no second manifest.
$pluginJson   = Join-Path $pluginRoot '.claude-plugin\plugin.json'
$changelog    = Join-Path $pluginRoot 'CHANGELOG.md'
$distRoot     = Join-Path $pluginRoot 'skills'
$manifestDir  = Join-Path $pluginRoot '.hash-record\publish'
$manifestFile = Join-Path $manifestDir 'last-manifest.txt'

# ── Source root ───────────────────────────────────────────────────────────────
if (-not $Source) { $Source = Join-Path $pluginRoot '..\skills' }
$sourceRoot = (Resolve-Path $Source).Path

# ── Deny-list ─────────────────────────────────────────────────────────────────
. (Join-Path $pluginRoot 'build\deny-list.ps1')

function Test-DotAncestor([string]$full, [string]$root) {
    $rel = $full.Substring($root.Length).TrimStart('\/')
    foreach ($seg in ($rel -split '[\/\\]')) { if ($seg.StartsWith('.')) { return $true } }
    return $false
}

# ── Blob hash (LF-normalized) ─────────────────────────────────────────────────
function Get-BlobHash([string]$path) {
    $bytes = [System.IO.File]::ReadAllBytes($path)
    $out   = [System.Collections.Generic.List[byte]]::new($bytes.Length)
    $i = 0
    while ($i -lt $bytes.Length) {
        if ($bytes[$i] -eq 13) {
            $out.Add(10)
            if ($i + 1 -lt $bytes.Length -and $bytes[$i + 1] -eq 10) { $i++ }
        } else { $out.Add($bytes[$i]) }
        $i++
    }
    $tmp = [System.IO.Path]::GetTempFileName()
    try {
        [System.IO.File]::WriteAllBytes($tmp, $out.ToArray())
        $h = (& git hash-object $tmp 2>$null)
        return ($LASTEXITCODE -eq 0 -and $h) ? $h.Trim() : $null
    } finally { Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue }
}

# ── Reference-chain inclusion ─────────────────────────────────────────────────
# Patterns that indicate a file reference inside a source file:
#   1. Backtick-quoted:  `filename.ext`  (markdown inline code)
#   2. Bare in shell command:  bash foo.sh / pwsh foo.ps1 / source foo.sh
# Patterns are matched relative to the directory of the file being scanned.
# Cross-folder refs (path separators) are resolved from the scanning dir.
# Refs escaping sourceRoot, hitting deny-list, or under dot-ancestors are dropped.

$script:_RefPatterns = @(
    # backtick-quoted: `path/to/file.ext` or `file.ext`
    [regex]'`([^`\r\n]+\.[a-zA-Z0-9]{1,8})`'
    # bare shell command token: bash/pwsh/sh/source/. followed by a word.ext token
    [regex]'(?:^|[\s;|])(?:bash|pwsh|sh|source|\.)\s+([\w./\\-]+\.[a-zA-Z0-9]{1,8})'
)

function Get-RefsFromContent([string]$content, [string]$srcDir) {
    $refs = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($pat in $script:_RefPatterns) {
        [regex]::Matches($content, $pat) | ForEach-Object {
            $raw = $_.Groups[1].Value.Trim()
            if (-not $raw) { return }
            # Skip glob wildcards, absolute Windows paths, and template/shell token chars
            # Do NOT filter ".." — path traversal is bounded post-resolution by sourceRoot check
            if ($raw -match '^\*|^[A-Za-z]:\\|[<>\$\[\]]') { return }
            $resolved = [System.IO.Path]::GetFullPath((Join-Path $srcDir $raw))
            [void]$refs.Add($resolved)
        }
    }
    return $refs
}

# Build-InclusionSet: walk the reference chain from SKILL.md in $skillSrcDir.
# Returns a HashSet[string] of absolute source paths that belong in the dist.
function Build-InclusionSet([string]$skillSrcDir) {
    $included = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $queue    = [System.Collections.Generic.Queue[string]]::new()
    $scanned  = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    $skillMd = Join-Path $skillSrcDir 'SKILL.md'
    if (-not (Test-Path $skillMd -PathType Leaf)) { return $included }

    [void]$included.Add($skillMd)
    $queue.Enqueue($skillMd)

    while ($queue.Count -gt 0) {
        $current = $queue.Dequeue()
        if (-not $scanned.Add($current)) { continue }   # already scanned

        $ext = [System.IO.Path]::GetExtension($current).ToLowerInvariant()
        # Only .md and .txt files embed references; binary/script files are leaf nodes
        if ($ext -notin @('.md', '.txt')) { continue }

        $content = Get-Content $current -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }

        $srcDir = Split-Path $current -Parent
        $refs   = Get-RefsFromContent $content $srcDir

        foreach ($resolved in $refs) {
            if (-not (Test-Path $resolved -PathType Leaf)) { continue }
            $fi = Get-Item $resolved
            if (-not $resolved.StartsWith($sourceRoot, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
            if (Test-DotAncestor $resolved $sourceRoot) { continue }
            if (Test-Denied $fi -or (Test-DotFile $fi)) { continue }
            if ($included.Add($resolved)) { $queue.Enqueue($resolved) }
        }
    }
    return $included
}

# ── Preflight ─────────────────────────────────────────────────────────────────
Write-Host "`n=== PRE-FLIGHT ==="

# R1 — dirty tree outside managed files (ignore untracked-only lines for gitignored paths)
Push-Location $pluginRoot
$dirty = & git status --porcelain 2>$null |
    Where-Object { $_ -notmatch '^\?\?' } |                              # skip untracked
    Where-Object { $_ -notmatch '^\s*\S+\s+(skills/|\.claude-plugin/|CHANGELOG\.md)' }
Pop-Location
if ($dirty) {
    Write-Error "Dirty working tree (unmanaged changes):`n$($dirty -join "`n")`nCommit or stash before publishing."
    exit 1
}

# R2 — on main branch
Push-Location $pluginRoot
$branch = (& git rev-parse --abbrev-ref HEAD 2>$null).Trim()
Pop-Location
if ($branch -ne 'main') {
    Write-Error "Not on main branch (currently: $branch). Switch to main before publishing."
    exit 1
}

# R3 — source exists
if (-not (Test-Path $sourceRoot)) {
    Write-Error "Source root not found: $sourceRoot"
    exit 1
}
$skillCount = (Get-ChildItem -Path $sourceRoot -Recurse -Filter 'SKILL.md' | Where-Object { -not (Test-DotAncestor $_.Directory.FullName $sourceRoot) }).Count
if ($skillCount -eq 0) {
    Write-Error "No SKILL.md-bearing directories found in source: $sourceRoot"
    exit 1
}

Write-Host "Branch: $branch | Source: $sourceRoot ($skillCount skills) | Bump: $Bump"

# ── Change detection ──────────────────────────────────────────────────────────
Write-Host "`n=== CHANGE CHECK ==="

$skillFolders = Get-ChildItem -Path $sourceRoot -Recurse -Filter 'SKILL.md' |
    Where-Object { -not (Test-DotAncestor $_.Directory.FullName $sourceRoot) } |
    Select-Object -ExpandProperty Directory | Sort-Object FullName

$newMap = [System.Collections.Generic.SortedDictionary[string,string]]::new([System.StringComparer]::Ordinal)
foreach ($dir in $skillFolders) {
    $inclusion = Build-InclusionSet $dir.FullName
    foreach ($srcFile in $inclusion) {
        $relFile = $srcFile.Substring($sourceRoot.Length).TrimStart('\/')
        $h = Get-BlobHash $srcFile
        if ($h) { $newMap["skills/$($relFile.Replace('\','/'))" ] = $h }
    }
}
foreach ($idxName in @('skill.index', 'skill.index.md')) {
    $p = Join-Path $sourceRoot $idxName
    if (Test-Path $p) { $h = Get-BlobHash $p; if ($h) { $newMap["skills/$idxName"] = $h } }
}

$changeCount = 0
if (Test-Path $manifestFile) {
    $storedMap = [System.Collections.Generic.Dictionary[string,string]]::new([System.StringComparer]::Ordinal)
    foreach ($line in (Get-Content $manifestFile | Where-Object { $_ -match ':' })) {
        $parts = $line -split ': ', 2
        if ($parts.Count -eq 2) { $storedMap[$parts[0]] = $parts[1] }
    }
    $added   = @($newMap.Keys | Where-Object { -not $storedMap.ContainsKey($_) })
    $removed = @($storedMap.Keys | Where-Object { -not $newMap.ContainsKey($_) })
    $changed = @($newMap.Keys | Where-Object { $storedMap.ContainsKey($_) -and $storedMap[$_] -ne $newMap[$_] })
    $changeCount = $added.Count + $removed.Count + $changed.Count
    if ($changeCount -gt 0) {
        Write-Host "Changes: +$($added.Count) -$($removed.Count) ~$($changed.Count)"
    } else {
        if (-not $Force) {
            Write-Host "No changes since last publish. Use -Force to republish anyway."
            exit 0
        }
        Write-Host "No changes but -Force set — proceeding."
    }
} else {
    Write-Host "No stored manifest — first publish."
}

# ── Compute new version ───────────────────────────────────────────────────────
$json = Get-Content $pluginJson -Raw | ConvertFrom-Json
$v = $json.version
if ($v -notmatch '^(\d+)\.(\d+)\.(\d+)$') { Write-Error "Invalid SemVer in plugin.json: $v"; exit 1 }
[int]$mj = $Matches[1]; [int]$mn = $Matches[2]; [int]$pt = $Matches[3]
switch ($Bump) {
    'patch' { $pt++ }
    'minor' { $mn++; $pt = 0 }
    'major' { $mj++; $mn = 0; $pt = 0 }
}
$newVer = "$mj.$mn.$pt"
$today  = Get-Date -Format 'yyyy-MM-dd'
Write-Host "`n=== RELEASE ===" 
Write-Host "Version: $v -> $newVer ($today)"

if ($DryRun) {
    Write-Host "`n[DRY RUN] Would: build dist ($($skillFolders.Count) skills), bump to $newVer, tag v$newVer, push."
    exit 0
}

# ── Build dist ────────────────────────────────────────────────────────────────
Write-Host "`n=== BUILD DIST ==="
Get-ChildItem -Path $distRoot | Remove-Item -Recurse -Force

$totalCopied = 0; $totalDenied = 0; $totalExcluded = 0

foreach ($dir in $skillFolders) {
    $inclusion = Build-InclusionSet $dir.FullName

    # Copy only files in the inclusion set; count others as excluded or denied
    Get-ChildItem -Path $dir.FullName -Recurse -File | ForEach-Object {
        $srcFile = $_.FullName
        if (Test-Denied $_ -or (Test-DotFile $_)) {
            $totalDenied++
        } elseif ($inclusion.Contains($srcFile)) {
            $relFile = $srcFile.Substring($sourceRoot.Length).TrimStart('\/')
            $dest    = Join-Path $distRoot $relFile
            New-Item -ItemType Directory -Path (Split-Path $dest -Parent) -Force | Out-Null
            Copy-Item $srcFile $dest -Force
            $totalCopied++
        } else {
            $totalExcluded++
        }
    }
}

foreach ($idxName in @('skill.index', 'skill.index.md')) {
    $src = Join-Path $sourceRoot $idxName
    if (Test-Path $src) { Copy-Item $src (Join-Path $distRoot $idxName) -Force; $totalCopied++ }
}

# Validation — no denied files in dist
$violations = Get-ChildItem -Path $distRoot -Recurse -File | Where-Object { Test-Denied $_ -or (Test-DotFile $_) }
if ($violations) {
    Write-Error "Build validation failed — denied files in dist:`n$($violations.FullName -join "`n")"
    exit 1
}

Write-Host "Dist: $($skillFolders.Count) skills | $totalCopied copied | $totalExcluded excluded | $totalDenied denied"

# ── Update plugin.json ────────────────────────────────────────────────────────
$json.version = $newVer
$json | Add-Member -NotePropertyName built -NotePropertyValue $today -Force
[System.IO.File]::WriteAllText($pluginJson, ($json | ConvertTo-Json -Depth 10) + "`n")
Write-Host "Wrote $pluginJson -> $newVer"

# ── Update CHANGELOG.md ───────────────────────────────────────────────────────
$entry   = "## [$newVer] - $today`n`n$Notes`n"
$existing = Get-Content $changelog -Raw
$header  = ($existing -split "`n" | Select-Object -First 3) -join "`n"
$body    = ($existing -split "`n" | Select-Object -Skip 3) -join "`n"
[System.IO.File]::WriteAllText($changelog, "$header`n`n$entry`n$($body.TrimStart())")

# ── Stage + commit ────────────────────────────────────────────────────────────
Write-Host "`n=== COMMIT ==="
Push-Location $pluginRoot
& git add .claude-plugin/plugin.json CHANGELOG.md skills/
& git commit -m "release: v$newVer"
Write-Host "Committed: release v$newVer"

# ── Tag ───────────────────────────────────────────────────────────────────────
& git tag -a "v$newVer" -m "v$newVer"
Write-Host "Tagged: v$newVer"
Pop-Location

# ── Save manifest ─────────────────────────────────────────────────────────────
New-Item -ItemType Directory -Path $manifestDir -Force | Out-Null
$manifestLines = $newMap.GetEnumerator() | ForEach-Object { "$($_.Key): $($_.Value)" }
[System.IO.File]::WriteAllText($manifestFile, ($manifestLines -join "`n") + "`n")

# ── Push ──────────────────────────────────────────────────────────────────────
Write-Host "`n=== PUSH ==="
Push-Location $pluginRoot
& git push origin main
& git push origin "v$newVer"
Pop-Location

Write-Host "`n=== DONE ==="
Write-Host "Released v$newVer | $($skillFolders.Count) skills | $totalCopied included | $totalExcluded excluded"
