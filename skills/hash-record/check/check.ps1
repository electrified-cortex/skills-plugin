# check.ps1 — hash-record cache probe
#Requires -Version 7
# Usage: check.ps1 <file_path> <op_kind> <record_filename>
# Outputs one of: HIT: <abs-path>   (file exists; caller reads)  (exit 0)
#                 MISS: <abs-path>  (file absent; caller writes)  (exit 0)
#                 ERROR: <reason>                                 (exit 1)
#
# Requires PowerShell 7+ (Microsoft PowerShell, cross-platform). Windows PowerShell 5.1 is not supported.

param(
    [string]$file_path,
    [string]$op_kind,
    [string]$record_filename,
    [switch]$help,
    [switch]$h
)

$ErrorActionPreference = 'Continue'

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
if ($help -or $h) {
    $usage = "Usage: check <file_path> <op_kind> <record_filename>`n" +
        "`n" +
        "Probe the hash-record cache for <file_path>.`n" +
        "`n" +
        "Arguments:`n" +
        "  file_path        Absolute path to the file to probe (must be readable).`n" +
        "  op_kind          Operation kind, e.g. `"markdown-hygiene`" or `"skill-auditing/v2`". May contain /.`n" +
        "  record_filename  Leaf filename, e.g. `"report.md`". No path separators.`n" +
        "`n" +
        "Output (stdout, one line):`n" +
        "  HIT: <abs-path>         Cache file exists; caller reads its contents.`n" +
        "  MISS: <abs-path>        No cache entry; this is the path to write to.`n" +
        "  ERROR: <reason>         Argument or runtime error.`n" +
        "`n" +
        "Exit codes:`n" +
        "  0   Success (HIT or MISS).`n" +
        "  1   Error.`n"
    [Console]::Out.Write($usage)
    exit 0
}

# ---------------------------------------------------------------------------
# Argument validation
# ---------------------------------------------------------------------------
if (-not $file_path -or -not $op_kind -or -not $record_filename) {
    [Console]::Out.Write("ERROR: missing arguments -- expected <file_path> <op_kind> <record_filename>`n")
    exit 1
}

# Reject path traversal in op_kind and record_filename
if ($op_kind -match '\.\.' -or $op_kind -match '[\\]') {
    [Console]::Out.Write("ERROR: invalid op_kind: $op_kind`n")
    exit 1
}

if ($record_filename -match '\.\.' -or $record_filename -match '[/\\]') {
    [Console]::Out.Write("ERROR: invalid record_filename: $record_filename`n")
    exit 1
}

# ---------------------------------------------------------------------------
# Helper: compute LF-normalized blob hash (CRLF/CR -> LF before hashing).
# Normalizes line endings before hashing so the result is identical regardless
# of platform git config, gitattributes, or calling CWD location.
# ---------------------------------------------------------------------------
function Get-LfBlobHash([string]$FilePath) {
    $bytes = [System.IO.File]::ReadAllBytes($FilePath)
    $out = [System.Collections.Generic.List[byte]]::new($bytes.Length)
    $i = 0
    while ($i -lt $bytes.Length) {
        if ($bytes[$i] -eq 13) {
            $out.Add(10)
            if ($i + 1 -lt $bytes.Length -and $bytes[$i + 1] -eq 10) { $i++ }
        } else {
            $out.Add($bytes[$i])
        }
        $i++
    }
    $tmp = [System.IO.Path]::GetTempFileName()
    try {
        [System.IO.File]::WriteAllBytes($tmp, $out.ToArray())
        $h = (& git hash-object $tmp 2>$null)
        if ($LASTEXITCODE -ne 0 -or -not $h) { return $null }
        return $h.Trim()
    } finally {
        Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------------------------
# Resolve repo root
# ---------------------------------------------------------------------------
$target_dir = Split-Path -Parent $file_path
$repo_root = (& git -C $target_dir rev-parse --show-toplevel 2>$null)
if (-not $repo_root) {
    $repo_root = $target_dir
    [Console]::Error.WriteLine("WARN: not in a git repo; falling back to file's parent dir as repo_root: $repo_root")
}
# Normalise slashes for path joining
$repo_root = $repo_root.TrimEnd('/', '\')

# ---------------------------------------------------------------------------
# Compute git blob hash (LF-normalized for cross-platform determinism)
# ---------------------------------------------------------------------------
$hash = Get-LfBlobHash $file_path
if (-not $hash) {
    [Console]::Out.Write("ERROR: git hash-object failed for: $file_path`n")
    exit 1
}

# ---------------------------------------------------------------------------
# Construct paths
# ---------------------------------------------------------------------------
$shard = $hash.Substring(0, 2)
# Normalise repo_root to forward-slash form for byte-identical stdout across runtimes
$repo_root = $repo_root -replace '\\', '/'
$cache_dir  = "$repo_root/.hash-record/$shard/$hash/$op_kind"
$cache_path = "$cache_dir/$record_filename"

# ---------------------------------------------------------------------------
# Probe cache — same path returned on HIT and MISS.
#   HIT  -> caller reads it.
#   MISS -> caller writes to it.
# ---------------------------------------------------------------------------
if (Test-Path -LiteralPath $cache_path -PathType Leaf) {
    [Console]::Out.Write("HIT: $cache_path`n")
    exit 0
}

# Cache miss
[Console]::Out.Write("MISS: $cache_path`n")
exit 0
