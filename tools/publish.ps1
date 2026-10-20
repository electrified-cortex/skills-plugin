#Requires -Version 7
# publish.ps1 — Cut a new release of skills-plugin.
#
# Usage:
#   publish.ps1 -Bump <patch|minor|major> -Notes "<release notes>" [-Source <path>] [-DryRun] [-Force] [-BuildOnly]
#
# -Bump      Required. SemVer increment: patch, minor, or major.
# -Notes     Required. Release notes for the annotated release tag.
# -Source    Override source root (default: sibling ../skills).
# -DryRun    All steps except commit/tag/push. Prints what would happen.
# -Force     Skip no-changes guard (re-publish identical content).
# -BuildOnly Validate + rebuild the dist tree, then stop — no version bump,
#            no commit/tag/push, no manifest update.

param(
    [Parameter(Mandatory)]
    [ValidateSet('patch','minor','major')]
    [string]$Bump,

    [Parameter(Mandatory)]
    [string]$Notes,

    [string]$Source,

    [switch]$DryRun,
    [switch]$Force,
    [switch]$BuildOnly
)

$ErrorActionPreference = 'Stop'

$pluginRoot   = Split-Path -Parent $PSScriptRoot
# Canonical version source: .claude-plugin/plugin.json — the manifest Claude
# Code reads when the plugin is installed. There is no second manifest.
$pluginJson   = Join-Path $pluginRoot '.claude-plugin\plugin.json'
$distRoot     = Join-Path $pluginRoot 'skills'
$agentsDist   = Join-Path $pluginRoot 'agents'
$manifestDir  = Join-Path $pluginRoot '.hash-record\publish'
$manifestFile = Join-Path $manifestDir 'last-manifest.txt'

# ── Source root ───────────────────────────────────────────────────────────────
if (-not $Source) { $Source = Join-Path $pluginRoot '..\skills' }
$sourceRoot = (Resolve-Path $Source).Path

# ── Deny-list ─────────────────────────────────────────────────────────────────
. (Join-Path $pluginRoot 'build\deny-list.ps1')

# ── Publish-ignore ────────────────────────────────────────────────────────────
# Optional <source>/.publish-ignore lists top-level source dirs (one per line,
# '#' starts a comment) that are excluded from the dist. The file lives in the
# source repo, not here, so unpublished skill names never appear in this repo.
$script:PublishIgnored = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$ignoreFile = Join-Path $sourceRoot '.publish-ignore'
if (-not (Test-Path $ignoreFile)) {
    # Fail closed: a missing ignore file must never degrade to publish-everything.
    Write-Error ".publish-ignore not found at $ignoreFile — refusing to build. Restore the file in the source repo (it is committed there) or pass -Source at a root that has one."
    exit 1
}
foreach ($line in Get-Content $ignoreFile) {
    $name = ($line -split '#', 2)[0].Trim()
    if ($name) { [void]$script:PublishIgnored.Add($name) }
}
function Test-Ignored([string]$full) {
    $rel = $full.Substring($sourceRoot.Length).TrimStart('\/')
    $top = ($rel -split '[\/\\]')[0]
    return $script:PublishIgnored.Contains($top)
}

# ── Source provenance + cleanliness pin ───────────────────────────────────────
# The dist must be built from a known source commit: record HEAD and refuse to
# build if the source tree is dirty anywhere outside ignored/dot dirs.
$script:SourceSha = (& git -C $sourceRoot rev-parse HEAD 2>$null)
$script:SourceSha = if ($script:SourceSha) { $script:SourceSha.Trim() } else { '(no-git)' }
$srcDirty = & git -C $sourceRoot status --porcelain 2>$null | Where-Object {
    $p = ($_ -replace '^.{2}\s+', '') -replace '"', ''
    if ($p -match '->') { $p = ($p -split '->')[-1].Trim() }
    $top = ($p -split '[\/\\]')[0]
    -not ($top.StartsWith('.') -or $script:PublishIgnored.Contains($top))
}
if ($srcDirty) {
    Write-Error "Source tree dirty outside ignored/dot dirs — commit first so the build is pinned to a reviewable SHA:`n$($srcDirty -join "`n")"
    exit 1
}

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

# ── Preflight ─────────────────────────────────────────────────────────────────
Write-Host "`n=== PRE-FLIGHT ==="

# R1 — dirty tree outside managed files (ignore untracked-only lines for gitignored paths)
if (-not $BuildOnly) {
    Push-Location $pluginRoot
    $dirty = & git status --porcelain 2>$null |
        Where-Object { $_ -notmatch '^\?\?' } |                              # skip untracked
        Where-Object { $_ -notmatch '^\s*\S+\s+(skills/|agents/|\.claude-plugin/)' }
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
} else {
    $branch = '(build-only)'
}

# R3 — source exists
if (-not (Test-Path $sourceRoot)) {
    Write-Error "Source root not found: $sourceRoot"
    exit 1
}
$skillCount = (Get-ChildItem -Path $sourceRoot -Recurse -Filter 'SKILL.md' |
    Where-Object { -not (Test-DotAncestor $_.Directory.FullName $sourceRoot) } |
    Where-Object { -not (Test-Ignored $_.Directory.FullName) }).Count
if ($skillCount -eq 0) {
    Write-Error "No SKILL.md-bearing directories found in source: $sourceRoot"
    exit 1
}

Write-Host "Branch: $branch | Source: $sourceRoot @ $script:SourceSha ($skillCount skills) | Bump: $Bump"

# ── Pre-publish validation ────────────────────────────────────────────────────
# Runs before any version bump / release tag. Rejects BOM'd or unparseable
# SKILL.md frontmatter and missing domain-flavor Inheritance declarations;
# warns (non-blocking) on dead directory references. See build/pre-publish-check.sh.
Write-Host "`n=== PRE-PUBLISH VALIDATION ==="
$prePublishCheck = Join-Path $pluginRoot 'build\pre-publish-check.sh'
# Prefer Git-for-Windows bash: on Windows, PATH `bash` is often the WSL stub,
# which fails when no distro is installed.
$bashPath = $null
$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if ($gitCmd) {
    $gitRoot = Split-Path (Split-Path $gitCmd.Source -Parent) -Parent
    $candidate = Join-Path $gitRoot 'bin\bash.exe'
    if (Test-Path $candidate) { $bashPath = $candidate }
}
if (-not $bashPath) {
    $bashCmd = Get-Command bash -ErrorAction SilentlyContinue
    if ($bashCmd) { $bashPath = $bashCmd.Source }
}
if (-not $bashPath) {
    Write-Error "bash not found (Git bin or PATH) — cannot run pre-publish validation (build/pre-publish-check.sh)."
    exit 1
}
& $bashPath $prePublishCheck $sourceRoot
if ($LASTEXITCODE -ne 0) {
    Write-Error "Pre-publish validation failed (exit $LASTEXITCODE). Fix the findings above before publishing."
    exit 1
}

# ── Change detection ──────────────────────────────────────────────────────────
Write-Host "`n=== CHANGE CHECK ==="

$skillFolders = Get-ChildItem -Path $sourceRoot -Recurse -Filter 'SKILL.md' |
    Where-Object { -not (Test-DotAncestor $_.Directory.FullName $sourceRoot) } |
    Where-Object { -not (Test-Ignored $_.Directory.FullName) } |
    Select-Object -ExpandProperty Directory | Sort-Object FullName

# ── Plugin agents ─────────────────────────────────────────────────────────────
# Claude Code registers plugin agents only from the plugin-root agents/ folder,
# never from inside a skill. Source convention: <skill>/agents/<name>.md is a
# Claude Code agent and is hoisted to agents/<name>.md. README.md and any
# subfolder (e.g. agents/vscode/) stay with the skill only — Claude Code scans
# agents/ recursively, so other runtimes' files must never land there.
Write-Host "`n=== AGENTS ==="
$agentFiles = @(foreach ($dir in $skillFolders) {
    $agentDir = Join-Path $dir.FullName 'agents'
    if (Test-Path $agentDir -PathType Container) {
        Get-ChildItem -Path $agentDir -File -Filter '*.md' |
            Where-Object { $_.Name -ne 'README.md' -and -not (Test-Denied $_) -and -not (Test-DotFile $_) }
    }
})
$agentByFile = @{}; $agentByName = @{}; $agentErrors = @()
foreach ($a in $agentFiles) {
    $srcRel = $a.FullName.Substring($sourceRoot.Length).TrimStart('\/')
    if ($agentByFile.ContainsKey($a.Name)) { $agentErrors += "duplicate agent file name '$($a.Name)': $srcRel and $($agentByFile[$a.Name])"; continue }
    $agentByFile[$a.Name] = $srcRel
    $text = (Get-Content $a.FullName -Raw) -replace "`r`n", "`n"
    if ($text -notmatch '(?s)\A---\n(.*?)\n---\n') { $agentErrors += "$srcRel - missing YAML frontmatter"; continue }
    $fm = $Matches[1]
    $name = if ($fm -match '(?m)^name:\s*(\S.*?)\s*$') { $Matches[1] } else { $null }
    # Without a name, a plugin agent loads under its file name (`x.agent.md` -> `x.agent`).
    if (-not $name) { $agentErrors += "$srcRel - frontmatter has no 'name'"; continue }
    $name = $name.Trim('"', "'")
    if ($name.Contains(':')) { $agentErrors += "$srcRel - agent name '$name' contains ':'" }
    if ($fm -notmatch '(?m)^description:\s*\S') { $agentErrors += "$srcRel - frontmatter has no 'description'" }
    # Plugin agents silently ignore these; shipping them would hide a broken guard.
    foreach ($k in 'hooks', 'mcpServers', 'permissionMode') {
        if ($fm -match "(?m)^${k}:") { $agentErrors += "$srcRel - '$k' is ignored in plugin agents; ship it as a plugin-wide component instead" }
    }
    $key = $name.ToLowerInvariant()
    if ($agentByName.ContainsKey($key)) { $agentErrors += "duplicate agent name '$name': $srcRel and $($agentByName[$key])" }
    else { $agentByName[$key] = $srcRel }
}
if ($agentErrors) {
    Write-Error "Agent validation failed:`n$($agentErrors -join "`n")"
    exit 1
}
$pluginName = (Get-Content $pluginJson -Raw | ConvertFrom-Json).name
foreach ($k in ($agentByName.Keys | Sort-Object)) { Write-Host "  ${pluginName}:$k  <- $($agentByName[$k])" }
Write-Host "Agents: $($agentFiles.Count)"

$newMap = [System.Collections.Generic.SortedDictionary[string,string]]::new([System.StringComparer]::Ordinal)
foreach ($a in $agentFiles) {
    $h = Get-BlobHash $a.FullName
    if ($h) { $newMap["agents/$($a.Name)"] = $h }
}
foreach ($dir in $skillFolders) {
    $relDir = $dir.FullName.Substring($sourceRoot.Length).TrimStart('\/')
    Get-ChildItem -Path $dir.FullName -File -Recurse | ForEach-Object {
        if (Test-DotAncestor $_.FullName $sourceRoot) { return }
        if ((Test-Denied $_) -or (Test-DotFile $_)) { return }
        $relFile = $_.FullName.Substring($dir.FullName.Length).TrimStart('\/').Replace('\','/')
        $h = Get-BlobHash $_.FullName
        if ($h) { $newMap["skills/$($relDir.Replace('\','/'))/$relFile"] = $h }
    }
}
foreach ($idxName in @('skill.index', 'skill.index.md')) {
    $p = Join-Path $sourceRoot $idxName
    if (Test-Path $p) { $h = Get-BlobHash $p; if ($h) { $newMap["skills/$idxName"] = $h } }
}

$changeCount = 0
if ($BuildOnly) {
    Write-Host "Build-only mode — skipping change detection."
} elseif (Test-Path $manifestFile) {
    $storedMap = [System.Collections.Generic.Dictionary[string,string]]::new([System.StringComparer]::Ordinal)
    foreach ($line in (Get-Content $manifestFile | Where-Object { $_ -match ':' -and -not $_.StartsWith('#') })) {
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
if (-not $BuildOnly) {
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
}

# DryRun must stop here regardless of -BuildOnly: everything below mutates the
# dist tree.
if ($DryRun) {
    Write-Host "`n[DRY RUN] Would rebuild dist ($($skillFolders.Count) skills) from $sourceRoot @ $script:SourceSha. Stopping."
    exit 0
}

# ── Build dist ────────────────────────────────────────────────────────────────
Write-Host "`n=== BUILD DIST ==="
Get-ChildItem -Path $distRoot | Remove-Item -Recurse -Force

$totalCopied = 0; $totalDenied = 0

$script:SourceRootPrefix = [System.IO.Path]::GetFullPath($sourceRoot).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar

function Resolve-Refs([string]$mdDest, [string]$srcDir, [int]$depth) {
    if ($depth -ge 4) { return }
    $content = Get-Content $mdDest -Raw -ErrorAction SilentlyContinue
    if (-not $content) { return }
    [regex]::Matches($content, '`([^`]+\.[a-zA-Z0-9]{2,6})`') | ForEach-Object {
        $ref = $_.Groups[1].Value.Trim()
        if ($ref.StartsWith('*/') -or $ref.StartsWith('../') -or $ref.StartsWith('..\') -or ($ref -match '^[A-Za-z]:') -or $ref.StartsWith('\\')) { return }
        $resolved = [System.IO.Path]::GetFullPath((Join-Path $srcDir $ref))
        # Containment gate FIRST: whatever separators or embedded '..' segments
        # the ref used, the canonical path must land under the source root.
        if (-not $resolved.StartsWith($script:SourceRootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) { return }
        if (-not (Test-Path $resolved -PathType Leaf)) { return }
        $fi = Get-Item $resolved
        if ($resolved.StartsWith($srcDir, [System.StringComparison]::OrdinalIgnoreCase)) { return }
        if ((Test-DotAncestor $resolved $sourceRoot) -or (Test-Ignored $resolved) -or (Test-Denied $fi)) { return }
        $relFromRoot = $resolved.Substring($sourceRoot.Length).TrimStart('\/')
        $dest        = Join-Path $distRoot $relFromRoot
        if (-not (Test-Path $dest)) {
            New-Item -ItemType Directory -Path (Split-Path $dest -Parent) -Force | Out-Null
            Copy-Item $fi.FullName $dest -Force
            if ($fi.Extension -eq '.md') { Resolve-Refs $dest (Split-Path $resolved -Parent) ($depth + 1) }
        }
    }
}

foreach ($dir in $skillFolders) {
    $relDir = $dir.FullName.Substring($sourceRoot.Length).TrimStart('\/')
    $dest   = Join-Path $distRoot $relDir
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    Get-ChildItem -Path $dir.FullName -File -Recurse | ForEach-Object {
        if (Test-DotAncestor $_.FullName $sourceRoot) { $totalDenied++; return }
        if ((Test-Denied $_) -or (Test-DotFile $_)) { $totalDenied++; return }
        $relFile  = $_.FullName.Substring($dir.FullName.Length).TrimStart('\/')
        $destFile = Join-Path $dest $relFile
        $destSub  = Split-Path $destFile -Parent
        if (-not (Test-Path $destSub)) { New-Item -ItemType Directory -Path $destSub -Force | Out-Null }
        Copy-Item $_.FullName $destFile -Force
        $totalCopied++
    }
    $destMd = Join-Path $dest 'SKILL.md'
    if (Test-Path $destMd) { Resolve-Refs $destMd $dir.FullName 0 }
}

foreach ($idxName in @('skill.index', 'skill.index.md')) {
    $src = Join-Path $sourceRoot $idxName
    if (Test-Path $src) { Copy-Item $src (Join-Path $distRoot $idxName) -Force; $totalCopied++ }
}

if (Test-Path $agentsDist) { Remove-Item -LiteralPath $agentsDist -Recurse -Force }
New-Item -ItemType Directory -Path $agentsDist -Force | Out-Null
foreach ($a in $agentFiles) { Copy-Item $a.FullName (Join-Path $agentsDist $a.Name) -Force; $totalCopied++ }

# Validation — no denied files in dist
$violations = Get-ChildItem -Path $distRoot, $agentsDist -Recurse -File | Where-Object { (Test-Denied $_) -or (Test-DotFile $_) }
if ($violations) {
    Write-Error "Build validation failed — denied files in dist:`n$($violations.FullName -join "`n")"
    exit 1
}

# Validation — no .publish-ignore'd name may appear as a dist top-level entry
$ignoredInDist = Get-ChildItem -Path $distRoot -Directory | Where-Object { $script:PublishIgnored.Contains($_.Name) }
if ($ignoredInDist) {
    Write-Error "Build validation failed — ignored skill dirs present in dist:`n$($ignoredInDist.FullName -join "`n")"
    exit 1
}

Write-Host "Dist: $($skillFolders.Count) skills | $($agentFiles.Count) agents | $totalCopied copied | $totalDenied denied"

if ($BuildOnly) {
    Write-Host "`n=== DONE (build-only) ==="
    Write-Host "Dist rebuilt and validated. No version bump, commit, tag, or push performed."
    exit 0
}

# ── Update plugin.json ────────────────────────────────────────────────────────
$json.version = $newVer
$json | Add-Member -NotePropertyName built -NotePropertyValue $today -Force
[System.IO.File]::WriteAllText($pluginJson, ($json | ConvertTo-Json -Depth 10) + "`n")
Write-Host "Wrote $pluginJson -> $newVer"

# ── Stage + commit ────────────────────────────────────────────────────────────
Write-Host "`n=== COMMIT ==="
Push-Location $pluginRoot
& git add -A -- .claude-plugin/plugin.json skills/ agents/
& git commit -m "release: v$newVer"
Write-Host "Committed: release v$newVer"

# ── Tag ───────────────────────────────────────────────────────────────────────
# Release notes live in the annotated tag — this repo carries no CHANGELOG.
# The source SHA pins which source-repo commit produced this release.
& git tag -a "v$newVer" -m "v$newVer`n`nsource: $script:SourceSha`n`n$Notes"
Write-Host "Tagged: v$newVer"
Pop-Location

# ── Save manifest ─────────────────────────────────────────────────────────────
New-Item -ItemType Directory -Path $manifestDir -Force | Out-Null
$manifestLines = @("# source: $script:SourceSha") + ($newMap.GetEnumerator() | ForEach-Object { "$($_.Key): $($_.Value)" })
[System.IO.File]::WriteAllText($manifestFile, ($manifestLines -join "`n") + "`n")

# ── Push ──────────────────────────────────────────────────────────────────────
Write-Host "`n=== PUSH ==="
Push-Location $pluginRoot
& git push origin main
& git push origin "v$newVer"
Pop-Location

Write-Host "`n=== DONE ==="
Write-Host "Released v$newVer | $($skillFolders.Count) skills | $totalCopied files"
