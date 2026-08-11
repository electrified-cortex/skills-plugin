#Requires -Version 7
# comment.ps1 — Post a comment on a GitHub issue via gh issue comment.
# Stdout: comment URL (single line) on success. Nothing else on stdout.
# Stderr: error messages.
# Exit codes: 0=posted, 2=usage error, 4=gh error.

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
function Show-Usage {
    @'
Usage: pwsh comment.ps1 [FLAGS]

Post a comment on a GitHub issue via gh issue comment.

Required flags:
  --owner <name>       GitHub org or user
  --repo <name>        Repository name
  --issue <num>        Issue number
  --body-file <path>   Path to a markdown body file (passed to gh by path)

Optional flags:
  --help, -h           Print this usage and exit 0

Stdout: comment URL on success (single LF-terminated line). Nothing else.
Exit:   0=posted  2=usage-error  4=gh-error
'@
}

# ---------------------------------------------------------------------------
# Flag parsing — manual, all flags kebab-case, no param() block
# ---------------------------------------------------------------------------
$owner    = ''
$repo     = ''
$issue    = ''
$bodyFile = ''

$i = 0
while ($i -lt $args.Count) {
    $flag = $args[$i]
    switch ($flag) {
        '--owner'     { $owner    = $args[$i+1]; $i += 2; break }
        '--repo'      { $repo     = $args[$i+1]; $i += 2; break }
        '--issue'     { $issue    = $args[$i+1]; $i += 2; break }
        '--body-file' { $bodyFile = $args[$i+1]; $i += 2; break }
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
# Validation
# ---------------------------------------------------------------------------
$missing = @()
if (-not $owner)    { $missing += '--owner' }
if (-not $repo)     { $missing += '--repo' }
if (-not $issue)    { $missing += '--issue' }
if (-not $bodyFile) { $missing += '--body-file' }

if ($missing.Count -gt 0) {
    [Console]::Error.WriteLine("USAGE_ERROR: missing required flags: $($missing -join ' ')")
    exit 2
}

if ($issue -notmatch '^\d+$') {
    [Console]::Error.WriteLine("USAGE_ERROR: --issue must be a positive integer, got: $issue")
    exit 2
}

if (-not (Test-Path -LiteralPath $bodyFile -PathType Leaf)) {
    [Console]::Error.WriteLine("USAGE_ERROR: --body-file not found: $bodyFile")
    exit 2
}

# ---------------------------------------------------------------------------
# Invoke gh issue comment via ProcessStartInfo (no command-string interpolation)
# ---------------------------------------------------------------------------
$psi = [System.Diagnostics.ProcessStartInfo]::new()
$psi.FileName               = 'gh'
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError  = $true
$psi.UseShellExecute        = $false

# Build argument list — one element per Add() call.
# Body file path is added as a single token; gh reads the file directly.
$psi.ArgumentList.Add('issue')
$psi.ArgumentList.Add('comment')
$psi.ArgumentList.Add($issue)
$psi.ArgumentList.Add('--repo')
$psi.ArgumentList.Add("$owner/$repo")
$psi.ArgumentList.Add('--body-file')
$psi.ArgumentList.Add($bodyFile)

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
# Emit comment URL to stdout (URL only, nothing else)
# ---------------------------------------------------------------------------
$commentUrl = $ghStdout.Trim()

if ([string]::IsNullOrEmpty($commentUrl)) {
    [Console]::Error.WriteLine("gh returned success but no URL in response")
    [Console]::Error.WriteLine($ghStdout)
    exit 4
}

# Write URL only — single LF-terminated line.
[Console]::Out.WriteLine($commentUrl)
