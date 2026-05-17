#!/usr/bin/env pwsh
# verify.ps1 — deterministic markdown hygiene check
# Covered rules: MD010, MD041, MONO-ESCAPE
# Usage: verify.ps1 <file> [-Ignore RULE[,RULE...]]
# Output: CLEAN | violation pairs (rule line + Fix line per violation), LF-terminated
# Exit: 0 on success; 1 on usage/file error (errors to stderr)
# Dependencies: pwsh 7.0+. No installs required.

[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory)]
    [string]$FilePath,

    [Parameter()]
    [string]$Ignore = ''
)
$ErrorActionPreference = 'Stop'

if (-not (Test-Path $FilePath -PathType Leaf)) {
    [Console]::Error.WriteLine("ERROR: file not found: $FilePath")
    exit 1
}

$skip = @{}
if ($Ignore) {
    foreach ($r in ($Ignore -split ',')) {
        $t = $r.Trim()
        if ($t) { $skip[$t] = $true }
    }
}

function Skip([string]$rule) { return $skip.ContainsKey($rule) }

$rawBytes = [System.IO.File]::ReadAllBytes($FilePath)
$rawText  = [System.Text.Encoding]::UTF8.GetString($rawBytes)

# Split on LF; handle CRLF by stripping CR from each line
$rawLines = $rawText -split "`n"
# Drop the empty element that appears when file ends with LF
if ($rawLines.Count -gt 0 -and $rawLines[-1] -eq '') {
    $lines = $rawLines[0..($rawLines.Count - 2)]
} else {
    $lines = $rawLines
}
$N = $lines.Count

$out = [System.Collections.Generic.List[string]]::new()

function Add-Finding([string]$finding, [string]$fix) {
    $out.Add($finding)
    $out.Add($fix)
}

# Detect YAML frontmatter for MD041 suppression
$hasFm = $false
foreach ($ln in $lines) {
    $stripped = $ln.TrimEnd("`r")
    if ($stripped -match '^\s*$') { continue }
    if ($stripped -eq '---') { $hasFm = $true }
    break
}

$inFence = $false

for ($i = 0; $i -lt $N; $i++) {
    $L = $lines[$i].TrimEnd("`r")  # normalize CRLF
    $LN = $i + 1

    $isFence = $false
    if ($L.StartsWith('```')) {
        $isFence = $true
        $inFence = -not $inFence
    }

    # MD010 — hard tabs outside fenced code blocks (skip fence delimiter lines)
    if (-not (Skip 'MD010') -and (-not $inFence) -and (-not $isFence) -and $L -match "`t") {
        Add-Finding "MD010 line ${LN}: hard tab in non-code content" `
                    "Fix: replace tab character on line ${LN} with spaces"
    }

    # MONO-ESCAPE — backslash-backtick inside inline code (outside fenced blocks)
    if (-not (Skip 'MONO-ESCAPE') -and (-not $inFence) -and (-not $isFence) -and $L.Contains('\`')) {
        Add-Finding "MONO-ESCAPE line ${LN}: [HIGH] backslash-backtick escape in inline code - breaks Markdown rendering" `
                    'Fix: use double-backtick fence: `` text with `backtick` `` instead of single-backtick + backslash-escape'
    }

}

# MD041 — first non-blank line must be H1 (suppressed when frontmatter detected)
if (-not (Skip 'MD041') -and -not $hasFm) {
    for ($i = 0; $i -lt $N; $i++) {
        $L = $lines[$i].TrimEnd("`r")
        if ($L -match '^\s*$') { continue }
        if (-not ($L -match '^# ')) {
            Add-Finding "MD041 line $($i + 1): first non-blank line is not an H1 heading" `
                        "Fix: add a top-level heading (# Title) as the first non-blank line of the file"
        }
        break
    }
}

# Output with explicit LF line endings (byte-identical with verify.sh on same platform)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
if ($out.Count -eq 0) {
    [Console]::Out.Write("CLEAN`n")
} else {
    [Console]::Out.Write(($out -join "`n") + "`n")
}
