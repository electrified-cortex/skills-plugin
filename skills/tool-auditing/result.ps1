#!/usr/bin/env pwsh
# result.ps1 — tool-auditing result tool
# Wraps hash-record-manifest and translates HIT into the cached audit verdict.
# Resolves the tool trio (<stem>.sh, <stem>.ps1, <stem>.spec.md) from tool_path.
# Usage: result <tool_path>
# Outputs one of:
#   PASS: <abs-path>                  (HIT, result: pass)               (exit 0)
#   PASS_WITH_FINDINGS: <abs-path>    (HIT, result: pass-with-findings) (exit 0)
#   FAIL: <abs-path>                  (HIT, result: fail)               (exit 0)
#   MISS: <abs-path>                  (no cache; this is the report path) (exit 0)
#   ERROR: <reason>                                                     (exit 1)

param(
    [Parameter(Position=0)]
    [string]$tool_path,
    [switch]$help,
    [switch]$h
)

$ErrorActionPreference = 'Continue'

if ($help -or $h) {
    [Console]::Out.Write(@"
Usage: result <tool_path>

Wraps hash-record-manifest for tool-auditing and translates a HIT into
the cached audit verdict. Resolves the tool trio from any input member.

Arguments:
  tool_path  Absolute path to ANY member of the tool trio:
             <stem>.sh, <stem>.ps1, or <stem>.spec.md.
             Missing trio members are reported as audit FAIL by the executor
             (Check 1). result builds the manifest from whichever exist.

Output (stdout, one line):
  PASS: <abs-path>                Cached report says result: pass.
  PASS_WITH_FINDINGS: <abs-path>  Cached report says result: pass-with-findings.
  FAIL: <abs-path>                Cached report says result: fail.
  MISS: <abs-path>                No cache entry; executor MUST write here.
  ERROR: <reason>                 Argument, runtime, or malformed-record error.

Exit codes:
  0  Success (PASS, PASS_WITH_FINDINGS, FAIL, or MISS).
  1  Error.
"@)
    exit 0
}

if (-not $tool_path) {
    [Console]::Out.Write("ERROR: missing argument -- expected <tool_path>`n")
    exit 1
}

if (-not (Test-Path -LiteralPath $tool_path -PathType Leaf)) {
    [Console]::Out.Write("ERROR: tool_path not found: $tool_path`n")
    exit 1
}

# Resolve dir + filename
$abs_tool = (Resolve-Path -LiteralPath $tool_path).Path
$tool_dir = Split-Path -Parent $abs_tool
$basename = Split-Path -Leaf $abs_tool

# Derive stem
if ($basename -like '*.spec.md') {
    $stem = $basename.Substring(0, $basename.Length - '.spec.md'.Length)
} elseif ($basename -like '*.sh') {
    $stem = $basename.Substring(0, $basename.Length - '.sh'.Length)
} elseif ($basename -like '*.ps1') {
    $stem = $basename.Substring(0, $basename.Length - '.ps1'.Length)
} else {
    [Console]::Out.Write("ERROR: unsupported tool extension: $basename`n")
    exit 1
}

# Resolve trio members
$sh_path = Join-Path $tool_dir "$stem.sh"
$ps1_path = Join-Path $tool_dir "$stem.ps1"
$spec_path = Join-Path $tool_dir "$stem.spec.md"

$files = @()
if (Test-Path -LiteralPath $sh_path -PathType Leaf) { $files += $sh_path }
if (Test-Path -LiteralPath $ps1_path -PathType Leaf) { $files += $ps1_path }
if (Test-Path -LiteralPath $spec_path -PathType Leaf) { $files += $spec_path }

# Locate sibling manifest tool
$script_dir = Split-Path -Parent $PSCommandPath
$manifest_ps1 = Join-Path $script_dir '../hash-record/hash-record-manifest/manifest.ps1'

if (-not (Test-Path -LiteralPath $manifest_ps1)) {
    [Console]::Out.Write("ERROR: cannot locate hash-record-manifest at: $manifest_ps1`n")
    exit 1
}

# Invoke manifest (op_kind v2 — trio scope)
try {
    $manifest_args = @('tool-auditing/v2', 'report.md') + $files
    $manifest_out = & pwsh -NoProfile -File $manifest_ps1 @manifest_args 2>$null
    $manifest_out = $manifest_out -join "`n" -replace "`r", '' -split "`n" | Where-Object { $_ -ne '' } | Select-Object -Last 1
} catch {
    [Console]::Out.Write("ERROR: hash-record-manifest failed for: $tool_path`n")
    exit 1
}

if (-not $manifest_out) {
    [Console]::Out.Write("ERROR: hash-record-manifest returned no output for: $tool_path`n")
    exit 1
}

$manifest_out = $manifest_out -replace '\\', '/'

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
    $result_line = (Get-Content $report_path -ErrorAction SilentlyContinue) | Where-Object { $_ -match '^result:' } | Select-Object -First 1
    if (-not $result_line) {
        [Console]::Out.Write("ERROR: malformed cache record at $report_path`n")
        exit 1
    }
    $result_value = ($result_line -split ':', 2)[1].Trim() -split '\s+' | Select-Object -First 1
    switch ($result_value) {
        'pass' {
            [Console]::Out.Write("PASS: $report_path`n")
            exit 0
        }
        'pass-with-findings' {
            [Console]::Out.Write("PASS_WITH_FINDINGS: $report_path`n")
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
