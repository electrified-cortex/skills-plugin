#!/usr/bin/env pwsh
# result.ps1 — markdown-hygiene result check
# Usage: result.ps1 <markdown_file_path> <filename>
# <filename>: report | lint | analysis  (bare name, no .md extension)
# Outputs one line:
#   CLEAN                        (report HIT, result: clean)
#   clean: <abs-path>            (non-report HIT, result: clean)
#   pass: <abs-path>             (HIT, result: pass)
#   findings: <abs-path>         (HIT, result: fail)
#   MISS: <abs-path>             (no cache entry)
#   ERROR: <reason>              (exit 1)

$ErrorActionPreference = 'Stop'

# Help
if ($args.Count -gt 0 -and ($args[0] -eq '--help' -or $args[0] -eq '-h')) {
    [Console]::Out.Write("Usage: result.ps1 <markdown_file_path> <filename>`n")
    exit 0
}

# Validate args
if ($args.Count -lt 1 -or -not $args[0]) {
    [Console]::Out.Write("ERROR: missing argument -- expected <markdown_file_path>`n")
    exit 1
}
if ($args.Count -lt 2 -or -not $args[1]) {
    [Console]::Out.Write("ERROR: missing filename argument`n")
    exit 1
}

$FilePath = $args[0]
$Filename = $args[1]

# Validate filename — no path separators or extension
if ($Filename -match '[/\\.]') {
    [Console]::Out.Write("ERROR: invalid filename: $Filename`n")
    exit 1
}

$RecordFile = "$Filename.md"

# Locate hash-record-check
$ScriptDir = Split-Path -Parent $PSCommandPath
$CheckPs1 = Join-Path $ScriptDir '../../hash-record/hash-record-check/check.ps1'

if (-not (Test-Path $CheckPs1)) {
    [Console]::Out.Write("ERROR: cannot locate hash-record-check at: $CheckPs1`n")
    exit 1
}

# Invoke hash-record-check
try {
    $CheckOut = & pwsh -NoProfile -File $CheckPs1 $FilePath 'markdown-hygiene' $RecordFile 2>$null
    $CheckOut = $CheckOut -join "`n" -replace "`r", '' -split "`n" | Where-Object { $_ -ne '' } | Select-Object -Last 1
} catch {
    [Console]::Out.Write("ERROR: hash-record-check failed for: $FilePath`n")
    exit 1
}

if (-not $CheckOut) {
    [Console]::Out.Write("ERROR: hash-record-check returned no output for: $FilePath`n")
    exit 1
}

# Normalize forward slashes
$CheckOut = $CheckOut -replace '\\', '/'

# Branch on hash-record-check stdout
if ($CheckOut -like 'MISS: *') {
    [Console]::Out.Write("$CheckOut`n")
    exit 0
}
if ($CheckOut -like 'ERROR: *') {
    [Console]::Out.Write("$CheckOut`n")
    exit 1
}
if ($CheckOut -like 'HIT: *') {
    $RecordPath = $CheckOut -replace '^HIT: ', ''
    if (-not (Test-Path $RecordPath)) {
        [Console]::Out.Write("ERROR: cache record vanished at: $RecordPath`n")
        exit 1
    }
    $ResultLine = (Get-Content $RecordPath -ErrorAction SilentlyContinue) |
        Where-Object { $_ -match '^result:' } | Select-Object -First 1
    if (-not $ResultLine) {
        [Console]::Out.Write("ERROR: malformed cache record at $RecordPath`n")
        exit 1
    }
    $ResultValue = ($ResultLine -split ':', 2)[1].Trim() -split '\s+' | Select-Object -First 1
    switch ($ResultValue) {
        'clean' {
            if ($Filename -eq 'report') {
                [Console]::Out.Write("CLEAN`n")
            } else {
                [Console]::Out.Write("clean: $RecordPath`n")
            }
            exit 0
        }
        'fail' {
            [Console]::Out.Write("findings: $RecordPath`n")
            exit 0
        }
        'pass' {
            [Console]::Out.Write("pass: $RecordPath`n")
            exit 0
        }
        default {
            [Console]::Out.Write("ERROR: malformed cache record at $RecordPath`n")
            exit 1
        }
    }
}

[Console]::Out.Write("ERROR: unrecognized hash-record-check output: $CheckOut`n")
exit 1
