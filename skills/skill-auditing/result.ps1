#!/usr/bin/env pwsh
# result.ps1 — skill-auditing result tool
# Wraps hash-record-manifest and translates HIT into the cached audit verdict.
# Usage: result <skill_dir>
# Outputs one of:
#   CLEAN: <abs-path>           (HIT, result: clean)        (exit 0)
#   PASS: <abs-path>            (HIT, result: pass)         (exit 0)
#   NEEDS_REVISION: <abs-path>  (HIT, result: findings)     (exit 0)
#   FAIL: <abs-path>            (HIT, result: fail)         (exit 0)
#   MISS: <abs-path>            (no cache; this is the report path) (exit 0)
#   ERROR: <reason>             (argument or runtime error) (exit 1)

param(
    [Parameter(Position=0)]
    [string]$skill_dir,
    [switch]$help,
    [switch]$h
)

$ErrorActionPreference = 'Stop'

if ($help -or $h) {
    [Console]::Out.Write(@"
Usage: result <skill_dir>

Wraps hash-record-manifest for skill-auditing and translates a HIT into
the cached audit verdict by reading the report's frontmatter.

Arguments:
  skill_dir        Absolute path to the skill folder being audited.

Options:
  --help / -h      Print usage, exit 0.

Output (stdout, one line):
  CLEAN: <abs-path>           Cached report says result: clean.
  PASS: <abs-path>            Cached report says result: pass.
  NEEDS_REVISION: <abs-path>  Cached report says result: findings.
  FAIL: <abs-path>            Cached report says result: fail.
  MISS: <abs-path>            No cache entry; executor MUST write here.
  ERROR: <reason>             Argument, runtime, or malformed-record error.

Exit codes:
  0  Success (PASS, NEEDS_REVISION, FAIL, or MISS).
  1  Error.
"@)
    exit 0
}

if (-not $skill_dir) {
    [Console]::Out.Write("ERROR: missing argument -- expected <skill_dir>`n")
    exit 1
}

$record_filename = 'report.md'

if (-not (Test-Path -LiteralPath $skill_dir -PathType Container)) {
    [Console]::Out.Write("ERROR: skill_dir not found: $skill_dir`n")
    exit 1
}

$skill_dir_full = (Resolve-Path -LiteralPath $skill_dir).Path

# Enumerate only the semantic content files the audit agent reads.
# Hashing all files causes indeterminism when non-semantic files (stamps,
# scripts, logs) are added/modified between the pre- and post-dispatch calls.
# Order is intentional — hash key must be identical between pre- and post-dispatch calls.
# Do not sort or reorder this list.
$semantic_names = @('SKILL.md', 'instructions.txt', 'spec.md', 'uncompressed.md', 'instructions.uncompressed.md')
$files = @()
foreach ($name in $semantic_names) {
    $candidate = Join-Path $skill_dir_full $name
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        $files += $candidate
    }
}

if ($files.Count -eq 0) {
    [Console]::Out.Write("ERROR: no semantic content files found in skill_dir`n")
    exit 1
}

# Single canonical op_kind
$op_kind = 'skill-auditing/v2'

# Locate sibling manifest tool
$script_dir = Split-Path -Parent $PSCommandPath
$manifest_ps1 = Join-Path $script_dir '../hash-record/hash-record-manifest/manifest.ps1'

if (-not (Test-Path -LiteralPath $manifest_ps1)) {
    [Console]::Out.Write("ERROR: cannot locate hash-record-manifest at: $manifest_ps1`n")
    exit 1
}

# Invoke manifest
try {
    $manifest_args = @($op_kind, $record_filename) + $files
    $manifest_out = & pwsh -NoProfile -File $manifest_ps1 @manifest_args
    $manifest_out = $manifest_out -join "`n" -replace "`r", '' -split "`n" | Where-Object { $_ -ne '' } | Select-Object -Last 1
} catch {
    [Console]::Out.Write("ERROR: hash-record-manifest failed for: $skill_dir_full`n")
    exit 1
}

if (-not $manifest_out) {
    [Console]::Out.Write("ERROR: hash-record-manifest returned no output for: $skill_dir_full`n")
    exit 1
}

# Normalize forward slashes
$manifest_out = $manifest_out -replace '\\', '/'

# Branch on manifest stdout
if ($manifest_out -like 'MISS: *') {
    [Console]::Out.Write("$manifest_out`n")
    exit 0
}
if ($manifest_out -like 'ERROR: *') {
    [Console]::Out.Write("$manifest_out`n")
    exit 1
}
if ($manifest_out -like 'HIT: *') {
    $report_path = $manifest_out -replace '^HIT: ', ''
    if (-not (Test-Path -LiteralPath $report_path)) {
        [Console]::Out.Write("ERROR: cache record vanished at: $report_path`n")
        exit 1
    }
    # Parse frontmatter result: line.
    $result_line = (Get-Content $report_path -ErrorAction SilentlyContinue) | Where-Object { $_ -match '^result:' } | Select-Object -First 1
    if (-not $result_line) {
        [Console]::Out.Write("ERROR: malformed cache record at $report_path`n")
        exit 1
    }
    $result_value = ($result_line -split ':', 2)[1].Trim() -split '\s+' | Select-Object -First 1
    switch ($result_value) {
        'clean' {
            [Console]::Out.Write("CLEAN: $report_path`n")
            exit 0
        }
        'pass' {
            [Console]::Out.Write("PASS: $report_path`n")
            exit 0
        }
        'findings' {
            [Console]::Out.Write("NEEDS_REVISION: $report_path`n")
            exit 0
        }
        'fail' {
            [Console]::Out.Write("FAIL: $report_path`n")
            exit 0
        }
        default {
            [Console]::Out.Write("ERROR: malformed cache record at $report_path`n")
            exit 1
        }
    }
}

[Console]::Out.Write("ERROR: unrecognized hash-record-manifest output: $manifest_out`n")
exit 1
