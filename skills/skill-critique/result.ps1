#!/usr/bin/env pwsh
# result.ps1 — skill-critique result tool
# Wraps hash-record/manifest and checks whether a critique at <tier> has already
# been run on the exact current content of the skill.
# Usage: result <skill_dir> <tier>
# Outputs one of:
#   PASS: <abs-path>    (HIT, cached critique report exists) (exit 0)
#   MISS: <abs-path>    (no cache; this is the report path)  (exit 0)
#   ERROR: <reason>     (argument or runtime error)          (exit 1)

# Arguments are read from $args, not a param() block: with declared parameters pwsh
# rejects a leading-dash value (such as -x) before this script runs.
$skill_dir = if ($args.Count -ge 1) { [string]$args[0] } else { '' }
$tier = if ($args.Count -ge 2) { [string]$args[1] } else { '' }

$ErrorActionPreference = 'Stop'

if ($skill_dir -ceq '--help' -or $skill_dir -ceq '-h') {
    [Console]::Out.Write(@"
Usage: result <skill_dir> <tier>

Wraps hash-record/manifest for skill-critique and checks whether a critique at
<tier> has already been run on the exact current content of the skill. Each tier
has its own cache entry.

Arguments:
  skill_dir        Absolute path to the skill folder being critiqued.
  tier             fast-cheap | standard | deep | fast-cheap-x3 (whole value,
                   case-sensitive).

Options:
  --help / -h      Print usage, exit 0.

Output (stdout, one line):
  PASS: <abs-path>    Cached critique report exists at <abs-path>.
  MISS: <abs-path>    No cache entry; executor MUST write here.
  ERROR: <reason>     Argument, runtime, or missing-dependency error.

Exit codes:
  0  Success (PASS or MISS).
  1  Error.
"@)
    exit 0
}

if ([string]::IsNullOrEmpty($skill_dir) -or [string]::IsNullOrEmpty($tier)) {
    [Console]::Out.Write("ERROR: missing argument -- expected <skill_dir> <tier>`n")
    exit 1
}

$record_filename = 'report.md'

# Whitelist: the whole value must equal one of the names below (case-sensitive).
$valid_tiers = @('fast-cheap', 'standard', 'deep', 'fast-cheap-x3')
if ($valid_tiers -cnotcontains $tier) {
    [Console]::Out.Write("ERROR: invalid tier -- expected fast-cheap, standard, deep or fast-cheap-x3`n")
    exit 1
}

if (-not (Test-Path -LiteralPath $skill_dir -PathType Container)) {
    [Console]::Out.Write("ERROR: skill_dir not found: $skill_dir`n")
    exit 1
}

$skill_dir_full = (Resolve-Path -LiteralPath $skill_dir).Path

# Enumerate only the semantic content files the critique agent reads.
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

# op_kind carries the tier: one cache entry per (skill hash, tier)
$op_kind = "skill-critique/v2/$tier"

# Locate sibling manifest tool
$script_dir = Split-Path -Parent $PSCommandPath
$manifest_ps1 = Join-Path $script_dir '../hash-record/manifest/manifest.ps1'

if (-not (Test-Path -LiteralPath $manifest_ps1)) {
    [Console]::Out.Write("ERROR: cannot locate hash-record/manifest at: $manifest_ps1`n")
    exit 1
}

# Invoke manifest
try {
    $manifest_args = @($op_kind, $record_filename) + $files
    $manifest_out = & pwsh -NoProfile -File $manifest_ps1 @manifest_args
    $manifest_out = $manifest_out -join "`n" -replace "`r", '' -split "`n" | Where-Object { $_ -ne '' } | Select-Object -Last 1
} catch {
    [Console]::Out.Write("ERROR: hash-record/manifest failed for: $skill_dir_full`n")
    exit 1
}

if (-not $manifest_out) {
    [Console]::Out.Write("ERROR: hash-record/manifest returned no output for: $skill_dir_full`n")
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
    [Console]::Out.Write("PASS: $report_path`n")
    exit 0
}

[Console]::Out.Write("ERROR: unrecognized hash-record/manifest output: $manifest_out`n")
exit 1
