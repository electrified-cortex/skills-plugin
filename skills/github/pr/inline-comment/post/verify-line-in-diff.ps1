# verify-line-in-diff.ps1 — Check whether a PR diff line is commentable
#Requires -Version 7
# Usage: verify-line-in-diff.ps1 OWNER REPO PR_NUMBER FILE_PATH LINE_NUMBER SIDE
# Outputs: IN_DIFF | NOT_IN_DIFF ranges:... | FILE_NOT_IN_DIFF | USAGE:... | API_ERROR:...
# Exit codes: 0=in_diff  1=not_in_diff  2=file_not_in_diff  3=usage_error  4=api_error
#
# Requires PowerShell 7+ (Microsoft PowerShell, cross-platform). Windows PowerShell 5.1 is not supported.

param(
    [string]$owner,
    [string]$repo,
    [string]$pr_number,
    [string]$file_path,
    [string]$line_number,
    [string]$side,
    [switch]$help,
    [switch]$h
)

$ErrorActionPreference = 'Continue'

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
if ($help -or $h) {
    [Console]::Out.Write(@'
Usage: verify-line-in-diff.ps1 OWNER REPO PR_NUMBER FILE_PATH LINE_NUMBER SIDE

Check whether LINE_NUMBER is within a commentable hunk range for FILE_PATH
in a GitHub pull request diff.

Arguments:
  OWNER        GitHub org or user name
  REPO         Repository name
  PR_NUMBER    Integer PR number
  FILE_PATH    Repo-relative path (e.g. src/foo.ts)
  LINE_NUMBER  Absolute line number to check
  SIDE         RIGHT (additions/context) or LEFT (deletions)

Output (stdout, one line):
  IN_DIFF                       Line is in a hunk range; safe to comment
  NOT_IN_DIFF ranges:<r1>,...   Line is not commentable; valid ranges listed
  FILE_NOT_IN_DIFF              File has no changes in this PR
  API_ERROR: <reason>           gh pr diff call failed
  USAGE: ...                    Bad arguments

Exit codes:
  0   IN_DIFF
  1   NOT_IN_DIFF
  2   FILE_NOT_IN_DIFF
  3   Bad arguments
  4   API error
'@)
    exit 0
}

# ---------------------------------------------------------------------------
# Argument validation
# ---------------------------------------------------------------------------
if (-not $owner -or -not $repo -or -not $pr_number -or -not $file_path -or -not $line_number -or -not $side) {
    [Console]::Out.Write("USAGE: verify-line-in-diff.ps1 OWNER REPO PR_NUMBER FILE_PATH LINE_NUMBER SIDE`n")
    exit 3
}

if ($side -ne 'RIGHT' -and $side -ne 'LEFT') {
    [Console]::Out.Write("USAGE: SIDE must be RIGHT or LEFT, got: $side`n")
    exit 3
}

if ($line_number -notmatch '^\d+$') {
    [Console]::Out.Write("USAGE: LINE_NUMBER must be a positive integer, got: $line_number`n")
    exit 3
}

if ($pr_number -notmatch '^\d+$') {
    [Console]::Out.Write("USAGE: PR_NUMBER must be a positive integer, got: $pr_number`n")
    exit 3
}

$line_num = [int]$line_number

# ---------------------------------------------------------------------------
# Fetch patch
# ---------------------------------------------------------------------------
$patch_output = & gh pr diff $pr_number --repo "$owner/$repo" --patch 2>&1
if ($LASTEXITCODE -ne 0) {
    [Console]::Error.WriteLine("API_ERROR: gh pr diff failed: $patch_output")
    [Console]::Out.Write("API_ERROR: gh pr diff failed`n")
    exit 4
}
$patch_lines = ($patch_output -join "`n") -split "`n"

# ---------------------------------------------------------------------------
# Parse hunk headers for file_path
# Hunk pattern: @@ -OLD[,OLD_LEN] +NEW[,NEW_LEN] @@
# Compact form: absent LEN means 1. LEN=0 means that side has no lines (skip).
# ---------------------------------------------------------------------------
$in_file    = $false
$found_file = $false
$ranges     = @()
$diff_header = "diff --git a/$file_path b/$file_path"
$hunk_re     = '^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@'

foreach ($line in $patch_lines) {
    if ($line.StartsWith('diff --git ')) {
        $in_file = ($line -eq $diff_header)
        if ($in_file) { $found_file = $true }
        continue
    }

    if ($in_file -and $line -match $hunk_re) {
        $old_start = [int]$Matches[1]
        $old_len   = if ($Matches[2]) { [int]$Matches[2] } else { 1 }
        $new_start = [int]$Matches[3]
        $new_len   = if ($Matches[4]) { [int]$Matches[4] } else { 1 }

        if ($side -eq 'RIGHT' -and $new_len -gt 0) {
            $ranges += @{ Start = $new_start; End = $new_start + $new_len - 1 }
        } elseif ($side -eq 'LEFT' -and $old_len -gt 0) {
            $ranges += @{ Start = $old_start; End = $old_start + $old_len - 1 }
        }
    }
}

# ---------------------------------------------------------------------------
# Result
# ---------------------------------------------------------------------------
if (-not $found_file) {
    [Console]::Out.Write("FILE_NOT_IN_DIFF`n")
    exit 2
}

$range_strs = @()
foreach ($r in $ranges) {
    $range_strs += "$($r.Start)-$($r.End)"
    if ($line_num -ge $r.Start -and $line_num -le $r.End) {
        [Console]::Out.Write("IN_DIFF`n")
        exit 0
    }
}

$joined = $range_strs -join ','
[Console]::Out.Write("NOT_IN_DIFF ranges:$joined`n")
exit 1
