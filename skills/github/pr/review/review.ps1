#Requires -Version 7
# review.ps1 — Submit or dismiss a pull request review via gh pr review.
# Stdout: PR URL (single line) on success. Nothing else on stdout.
# Stderr: error messages.
# Exit codes: 0=submitted, 2=usage error, 4=gh error.

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
function Show-Usage {
    @'
Usage: pwsh review.ps1 [FLAGS]

Submit or dismiss a pull request review via gh pr review.

Required flags:
  --owner <name>       GitHub org or user
  --repo <name>        Repository name
  --pr <num>           PR number
  --decision <value>   One of: approve, request-changes, comment, dismiss

Conditional flags:
  --body-file <path>   Path to a markdown body file (required for request-changes
                       and comment; optional for approve and dismiss)
  --review-id <id>     Review ID (required for dismiss)

Optional flags:
  --help, -h           Print this usage and exit 0

Stdout: PR URL on success (single LF-terminated line). Nothing else.
Exit:   0=submitted  2=usage-error  4=gh-error
'@
}

# ---------------------------------------------------------------------------
# Flag parsing — manual, all flags kebab-case, no param() block
# ---------------------------------------------------------------------------
$owner    = ''
$repo     = ''
$pr       = ''
$decision = ''
$bodyFile = ''
$reviewId = ''

$i = 0
while ($i -lt $args.Count) {
    $flag = $args[$i]
    switch ($flag) {
        '--owner'     { $owner    = $args[$i+1]; $i += 2; break }
        '--repo'      { $repo     = $args[$i+1]; $i += 2; break }
        '--pr'        { $pr       = $args[$i+1]; $i += 2; break }
        '--decision'  { $decision = $args[$i+1]; $i += 2; break }
        '--body-file' { $bodyFile = $args[$i+1]; $i += 2; break }
        '--review-id' { $reviewId = $args[$i+1]; $i += 2; break }
        { $_ -in '--help', '-h' } {
            Show-Usage
            exit 0
        }
        default {
            [Console]::Error.WriteLine("USAGE_ERROR: unknown flag: $flag")
            exit 2
        }
    }
}

# ---------------------------------------------------------------------------
# Validation — required flags
# ---------------------------------------------------------------------------
$missing = @()
if (-not $owner)    { $missing += '--owner' }
if (-not $repo)     { $missing += '--repo' }
if (-not $pr)       { $missing += '--pr' }
if (-not $decision) { $missing += '--decision' }

if ($missing.Count -gt 0) {
    [Console]::Error.WriteLine("USAGE_ERROR: missing required flags: $($missing -join ' ')")
    exit 2
}

# ---------------------------------------------------------------------------
# Validation — --decision enum
# ---------------------------------------------------------------------------
$validDecisions = @('approve', 'request-changes', 'comment', 'dismiss')
if ($decision -notin $validDecisions) {
    [Console]::Error.WriteLine("USAGE_ERROR: --decision must be one of: approve, request-changes, comment, dismiss; got: $decision")
    exit 2
}

# ---------------------------------------------------------------------------
# Validation — --pr is a positive integer
# ---------------------------------------------------------------------------
if ($pr -notmatch '^\d+$') {
    [Console]::Error.WriteLine("USAGE_ERROR: --pr must be a positive integer, got: $pr")
    exit 2
}

# ---------------------------------------------------------------------------
# Validation — conditional flags
# ---------------------------------------------------------------------------
if ($decision -in @('request-changes', 'comment') -and -not $bodyFile) {
    [Console]::Error.WriteLine("USAGE_ERROR: --body-file is required when --decision is $decision")
    exit 2
}

if ($decision -eq 'dismiss' -and -not $reviewId) {
    [Console]::Error.WriteLine("USAGE_ERROR: --review-id is required when --decision is dismiss")
    exit 2
}

if ($bodyFile -and -not (Test-Path -LiteralPath $bodyFile -PathType Leaf)) {
    [Console]::Error.WriteLine("USAGE_ERROR: --body-file not found: $bodyFile")
    exit 2
}

# ---------------------------------------------------------------------------
# Map --decision to gh flag
# ---------------------------------------------------------------------------
$ghFlag = switch ($decision) {
    'approve'          { '--approve' }
    'request-changes'  { '--request-changes' }
    'comment'          { '--comment' }
    'dismiss'          { '--dismiss' }
}

# ---------------------------------------------------------------------------
# Invoke gh pr review via ProcessStartInfo (no command-string interpolation)
# ---------------------------------------------------------------------------
$psi = [System.Diagnostics.ProcessStartInfo]::new()
$psi.FileName               = 'gh'
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError  = $true
$psi.UseShellExecute        = $false

# Build argument list — one element per Add() call.
$psi.ArgumentList.Add('pr')
$psi.ArgumentList.Add('review')
$psi.ArgumentList.Add($pr)
$psi.ArgumentList.Add('--repo')
$psi.ArgumentList.Add("$owner/$repo")
$psi.ArgumentList.Add($ghFlag)

if ($reviewId) {
    $psi.ArgumentList.Add('--review-id')
    $psi.ArgumentList.Add($reviewId)
}

if ($bodyFile) {
    $psi.ArgumentList.Add('--body-file')
    $psi.ArgumentList.Add($bodyFile)
}

$proc = [System.Diagnostics.Process]::new()
$proc.StartInfo = $psi
[void]$proc.Start()

$ghStdout = $proc.StandardOutput.ReadToEnd()
$ghStderr  = $proc.StandardError.ReadToEnd()
$proc.WaitForExit()
$ghExit = $proc.ExitCode

# ---------------------------------------------------------------------------
# Handle gh errors
# ---------------------------------------------------------------------------
if ($ghExit -ne 0) {
    [Console]::Error.WriteLine($ghStderr)
    exit 4
}

# ---------------------------------------------------------------------------
# gh pr review emits no URL on success — retrieve via gh pr view
# ---------------------------------------------------------------------------
$psiUrl = [System.Diagnostics.ProcessStartInfo]::new()
$psiUrl.FileName               = 'gh'
$psiUrl.RedirectStandardOutput = $true
$psiUrl.RedirectStandardError  = $true
$psiUrl.UseShellExecute        = $false

$psiUrl.ArgumentList.Add('pr')
$psiUrl.ArgumentList.Add('view')
$psiUrl.ArgumentList.Add($pr)
$psiUrl.ArgumentList.Add('--repo')
$psiUrl.ArgumentList.Add("$owner/$repo")
$psiUrl.ArgumentList.Add('--json')
$psiUrl.ArgumentList.Add('url')
$psiUrl.ArgumentList.Add('--jq')
$psiUrl.ArgumentList.Add('.url')

$procUrl = [System.Diagnostics.Process]::new()
$procUrl.StartInfo = $psiUrl
[void]$procUrl.Start()

$urlStdout = $procUrl.StandardOutput.ReadToEnd()
$urlStderr  = $procUrl.StandardError.ReadToEnd()
$procUrl.WaitForExit()
$urlExit = $procUrl.ExitCode

if ($urlExit -ne 0) {
    [Console]::Error.WriteLine($urlStderr)
    exit 4
}

$prUrl = $urlStdout.Trim()

if ([string]::IsNullOrEmpty($prUrl)) {
    [Console]::Error.WriteLine("gh pr view returned success but no URL in response")
    exit 4
}

# Write URL only — single LF-terminated line.
[Console]::Out.WriteLine($prUrl)
