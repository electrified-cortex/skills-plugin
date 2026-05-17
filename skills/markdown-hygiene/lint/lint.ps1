#!/usr/bin/env pwsh
# lint.ps1 — in-place auto-fix: MD009 (trailing spaces), MD012 (consecutive blank lines), MD047 (trailing newline)
# Usage: lint.ps1 <path-or-glob> [<path-or-glob> ...]
# Exit: 0 all matched files processed; 1 usage error or plain path not found/writable
# Deps: pwsh 7.0+. No external tools.

[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory, ValueFromRemainingArguments)]
    [string[]]$Patterns
)
$ErrorActionPreference = 'Stop'

function Invoke-LintFile([string]$FilePath) {
    if (-not (Test-Path $FilePath -PathType Leaf)) {
        [Console]::Error.WriteLine("ERROR: file not found: $FilePath")
        return $false
    }
    if (([System.IO.FileInfo]$FilePath).IsReadOnly) {
        [Console]::Error.WriteLine("ERROR: file not writable: $FilePath")
        return $false
    }

    $rawText = [System.IO.File]::ReadAllText($FilePath, [System.Text.UTF8Encoding]::new($false))

    # Split on LF; handle CRLF by stripping CR per line
    $rawLines = $rawText -split "`n"
    # Drop trailing empty element when file ends with LF
    if ($rawLines.Count -gt 0 -and $rawLines[-1] -eq '') {
        $rawLines = $rawLines[0..($rawLines.Count - 2)]
    }

    $result = [System.Collections.Generic.List[string]]::new()
    $prevBlank = $false

    foreach ($line in $rawLines) {
        $L = $line.TrimEnd("`r")   # normalize CRLF
        # MD009: strip trailing whitespace
        $L = $L.TrimEnd()
        # MD012: collapse consecutive blank lines
        if ($L -match '^\s*$') {
            if ($prevBlank) { continue }
            $prevBlank = $true
        } else {
            $prevBlank = $false
        }
        $result.Add($L)
    }

    # Write UTF-8 no BOM, LF endings; MD047: append final LF
    $content = if ($result.Count -gt 0) { ($result -join "`n") + "`n" } else { '' }
    [System.IO.File]::WriteAllText($FilePath, $content, [System.Text.UTF8Encoding]::new($false))
    return $true
}

$exitCode = 0
foreach ($pattern in $Patterns) {
    # Determine if pattern is a glob (contains * or ?)
    $isGlob = $pattern -match '[*?]'
    if ($isGlob) {
        $matched = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue
        foreach ($item in $matched) {
            if (-not (Invoke-LintFile $item.FullName)) { $exitCode = 1 }
        }
    } else {
        if (-not (Invoke-LintFile $pattern)) { $exitCode = 1 }
    }
}
exit $exitCode
