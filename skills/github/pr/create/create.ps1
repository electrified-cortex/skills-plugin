#Requires -Version 7
# create.ps1 — Open a pull request via gh pr create.
# Stdout: PR URL (single line) on success. Nothing else on stdout.
# Stderr: error messages.
# Exit codes: 0=created, 2=usage error, 4=gh error.

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
function Show-Usage {
    @'
Usage: pwsh create.ps1 [FLAGS]

Open a pull request via gh pr create.

Required flags:
  --owner <name>       GitHub org or user
  --repo <name>        Repository name
  --base <branch>      Base branch (e.g., main)
  --title <text>       PR title
  --body-file <path>   Path to a markdown body file (passed to gh by path)

Optional flags:
  --label <labels>     Comma-separated label names
  --draft              Create as draft PR
  --help, -h           Print this usage and exit 0

Stdout: PR URL on success (single LF-terminated line). Nothing else.
Exit:   0=created  2=usage-error  4=gh-error
'@
}

# ---------------------------------------------------------------------------
# Flag parsing — manual, all flags kebab-case, no param() block
# ---------------------------------------------------------------------------
$owner    = ''
$repo     = ''
$base     = ''
$title    = ''
$bodyFile = ''
$label    = ''
$draft    = $false

$i = 0
while ($i -lt $args.Count) {
    $flag = $args[$i]
    switch ($flag) {
        '--owner'     { $owner    = $args[$i+1]; $i += 2; break }
        '--repo'      { $repo     = $args[$i+1]; $i += 2; break }
        '--base'      { $base     = $args[$i+1]; $i += 2; break }
        '--title'     { $title    = $args[$i+1]; $i += 2; break }
        '--body-file' { $bodyFile = $args[$i+1]; $i += 2; break }
        '--label'     { $label    = $args[$i+1]; $i += 2; break }
        '--draft'     { $draft    = $true;        $i += 1; break }
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
if (-not $base)     { $missing += '--base' }
if (-not $title)    { $missing += '--title' }
if (-not $bodyFile) { $missing += '--body-file' }

if ($missing.Count -gt 0) {
    [Console]::Error.WriteLine("USAGE_ERROR: missing required flags: $($missing -join ' ')")
    exit 2
}

if (-not (Test-Path -LiteralPath $bodyFile -PathType Leaf)) {
    [Console]::Error.WriteLine("USAGE_ERROR: --body-file not found: $bodyFile")
    exit 2
}

# ---------------------------------------------------------------------------
# Invoke gh pr create via ProcessStartInfo (no command-string interpolation)
# ---------------------------------------------------------------------------
$psi = [System.Diagnostics.ProcessStartInfo]::new()
$psi.FileName               = 'gh'
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError  = $true
$psi.UseShellExecute        = $false

# Build argument list — one element per Add() call.
# Body file path is added as a single token; gh reads the file directly.
$psi.ArgumentList.Add('pr')
$psi.ArgumentList.Add('create')
$psi.ArgumentList.Add('--repo')
$psi.ArgumentList.Add("$owner/$repo")
$psi.ArgumentList.Add('--base')
$psi.ArgumentList.Add($base)
$psi.ArgumentList.Add('--title')
$psi.ArgumentList.Add($title)
$psi.ArgumentList.Add('--body-file')
$psi.ArgumentList.Add($bodyFile)

if ($label) {
    $psi.ArgumentList.Add('--label')
    $psi.ArgumentList.Add($label)
}

if ($draft) {
    $psi.ArgumentList.Add('--draft')
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
# Emit PR URL to stdout (URL only, nothing else)
# ---------------------------------------------------------------------------
$prUrl = $ghStdout.Trim()

if ([string]::IsNullOrEmpty($prUrl)) {
    [Console]::Error.WriteLine("gh returned success but no URL in response")
    [Console]::Error.WriteLine($ghStdout)
    exit 4
}

# Write URL only — single LF-terminated line.
[Console]::Out.WriteLine($prUrl)
