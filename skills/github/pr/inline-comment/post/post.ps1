#Requires -Version 7
# post.ps1 — Post a PR inline review comment via gh api.
# Stdout: html_url (single line) on success. Nothing else on stdout.
# Stderr: error messages.
# Exit codes: 0=posted, 2=usage error, 3=line not in diff, 4=gh error.

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
function Show-Usage {
    @'
Usage: pwsh post.ps1 [FLAGS]

Post a single PR inline review comment via gh api.

Required flags:
  --owner <name>       GitHub org or user
  --repo <name>        Repository name
  --pr <num>           PR number
  --commit-sha <sha>   Head commit SHA
  --file <path>        Repo-relative file path
  --line <int>         Absolute line number
  --body-file <path>   Path to a markdown body file (passed to gh by path)

Optional flags:
  --side LEFT|RIGHT    Diff side (default: RIGHT)
  --help, -h           Print this usage and exit 0

Stdout: html_url on success (single LF-terminated line). Nothing else.
Exit:   0=posted  2=usage-error  3=line-not-in-diff  4=gh-error
'@
}

# ---------------------------------------------------------------------------
# Flag parsing — manual, all flags kebab-case, no param() block
# ---------------------------------------------------------------------------
$owner     = ''
$repo      = ''
$pr        = ''
$commitSha = ''
$file      = ''
$line      = ''
$side      = 'RIGHT'
$bodyFile  = ''

$i = 0
while ($i -lt $args.Count) {
    $flag = $args[$i]
    switch ($flag) {
        '--owner'      { $owner     = $args[$i+1]; $i += 2; break }
        '--repo'       { $repo      = $args[$i+1]; $i += 2; break }
        '--pr'         { $pr        = $args[$i+1]; $i += 2; break }
        '--commit-sha' { $commitSha = $args[$i+1]; $i += 2; break }
        '--file'       { $file      = $args[$i+1]; $i += 2; break }
        '--line'       { $line      = $args[$i+1]; $i += 2; break }
        '--side'       { $side      = $args[$i+1]; $i += 2; break }
        '--body-file'  { $bodyFile  = $args[$i+1]; $i += 2; break }
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
if (-not $owner)     { $missing += '--owner' }
if (-not $repo)      { $missing += '--repo' }
if (-not $pr)        { $missing += '--pr' }
if (-not $commitSha) { $missing += '--commit-sha' }
if (-not $file)      { $missing += '--file' }
if (-not $line)      { $missing += '--line' }
if (-not $bodyFile)  { $missing += '--body-file' }

if ($missing.Count -gt 0) {
    [Console]::Error.WriteLine("USAGE_ERROR: missing required flags: $($missing -join ' ')")
    exit 2
}

if ($pr -notmatch '^\d+$') {
    [Console]::Error.WriteLine("USAGE_ERROR: --pr must be a positive integer, got: $pr")
    exit 2
}

if ($line -notmatch '^\d+$' -or [int]$line -eq 0) {
    [Console]::Error.WriteLine("USAGE_ERROR: --line must be a positive integer, got: $line")
    exit 2
}

if ($side -ne 'LEFT' -and $side -ne 'RIGHT') {
    [Console]::Error.WriteLine("USAGE_ERROR: --side must be LEFT or RIGHT, got: $side")
    exit 2
}

if (-not (Test-Path -LiteralPath $bodyFile -PathType Leaf)) {
    [Console]::Error.WriteLine("USAGE_ERROR: --body-file not found: $bodyFile")
    exit 2
}

# ---------------------------------------------------------------------------
# Read body content and build JSON payload
# ---------------------------------------------------------------------------
# We read the file here (UTF-8, no BOM) and serialize the entire payload via
# ConvertTo-Json rather than relying on gh's --field body=@<path> reader.
# gh's @file handling on Windows mangles backticks and can drop characters
# due to its type-inference pass over the file content.
$bodyContent = Get-Content -LiteralPath $bodyFile -Raw -Encoding utf8
if ($null -eq $bodyContent) { $bodyContent = '' }

$payload = [ordered]@{
    body      = $bodyContent
    commit_id = $commitSha
    path      = $file
    line      = [int]$line
    side      = $side
} | ConvertTo-Json -Depth 2 -Compress

# ---------------------------------------------------------------------------
# Invoke gh api via ProcessStartInfo (no command-string interpolation)
# ---------------------------------------------------------------------------
$psi = [System.Diagnostics.ProcessStartInfo]::new()
$psi.FileName               = 'gh'
$psi.RedirectStandardInput  = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError  = $true
$psi.UseShellExecute        = $false

# Pipe the pre-built JSON payload via --input - instead of using
# --field body=@<path> to avoid gh's @file reader on Windows.
$psi.ArgumentList.Add('api')
$psi.ArgumentList.Add('--method')
$psi.ArgumentList.Add('POST')
$psi.ArgumentList.Add("repos/$owner/$repo/pulls/$pr/comments")
$psi.ArgumentList.Add('--input')
$psi.ArgumentList.Add('-')

$proc = [System.Diagnostics.Process]::new()
$proc.StartInfo = $psi
[void]$proc.Start()

# Write JSON payload to stdin, then close to signal EOF.
$proc.StandardInput.Write($payload)
$proc.StandardInput.Close()

# Read stdout and stderr asynchronously to avoid buffer-full deadlock.
$stdoutTask = $proc.StandardOutput.ReadToEndAsync()
$stderrTask = $proc.StandardError.ReadToEndAsync()
$proc.WaitForExit()
$ghStdout = $stdoutTask.Result
$ghStderr  = $stderrTask.Result
$ghExit = $proc.ExitCode

# ---------------------------------------------------------------------------
# Handle gh errors
# ---------------------------------------------------------------------------
if ($ghExit -ne 0) {
    # Detect line-not-in-diff: HTTP 422 with line-resolution error text from gh.
    if ($ghStderr -match '422' -and
        ($ghStderr -match 'pull_request_review_thread\.line' -or
         $ghStderr -match 'could not be resolved' -or
         $ghStderr -match 'line is not part of the diff' -or
         $ghStderr -match 'not part of the pull request diff')) {
        [Console]::Error.WriteLine("line not in diff for side $side (422 from gh api)")
        exit 3
    }
    # All other gh errors → exit 4.
    [Console]::Error.WriteLine($ghStderr)
    exit 4
}

# ---------------------------------------------------------------------------
# Extract html_url and emit to stdout (URL only, nothing else)
# ---------------------------------------------------------------------------
try {
    $json = $ghStdout | ConvertFrom-Json -ErrorAction Stop
} catch {
    [Console]::Error.WriteLine("gh returned success but response is not valid JSON")
    [Console]::Error.WriteLine($ghStdout)
    exit 4
}

$htmlUrl = $json.html_url
if ([string]::IsNullOrEmpty($htmlUrl)) {
    [Console]::Error.WriteLine("gh returned success but html_url missing in response")
    [Console]::Error.WriteLine($ghStdout)
    exit 4
}

# Write URL only — single LF-terminated line.
[Console]::Out.WriteLine($htmlUrl)
