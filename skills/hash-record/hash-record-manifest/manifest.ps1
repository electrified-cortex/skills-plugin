# manifest.ps1 — hash-record multi-file manifest probe
# Usage: manifest.ps1 <op_kind> <record_filename> <file1> [<file2> ...]
# Outputs one of: HIT: <abs-path>   (file exists; caller reads)  (exit 0)
#                 MISS: <abs-path>  (file absent; caller writes)  (exit 0)
#                 ERROR: <reason>                                 (exit 1)
#
# Requires PowerShell 7+ (Microsoft PowerShell, cross-platform). Windows PowerShell 5.1 is not supported.

param(
    [Parameter(Position=0)]
    [string]$op_kind,
    [Parameter(Position=1)]
    [string]$record_filename,
    [Parameter(Position=2, ValueFromRemainingArguments=$true)]
    [string[]]$files,
    [switch]$help,
    [switch]$h
)

$ErrorActionPreference = 'Continue'

if ($help -or $h) {
    $usage = "Usage: manifest <op_kind> <record_filename> <file1> [<file2> ...]`n" +
        "`n" +
        "Probe the hash-record cache for a set of files via a combined manifest hash.`n" +
        "`n" +
        "Arguments:`n" +
        "  op_kind          Operation kind, e.g. `"markdown-hygiene`" or `"skill-auditing/v2`".`n" +
        "                   May contain /. Must NOT contain .., \, or *.`n" +
        "  record_filename  Leaf filename, e.g. `"report.md`". No path separators.`n" +
        "  file1 ...        One or more file paths (relative or absolute, must be readable).`n" +
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

if (-not $op_kind -or -not $record_filename -or -not $files -or $files.Count -eq 0) {
    [Console]::Out.Write("ERROR: missing arguments -- expected <op_kind> <record_filename> <file1> [<file2> ...]`n")
    exit 1
}

# Validate op_kind: reject '..', '\', '*' — but allow '/' for versioning
if ($op_kind -match '\.\.' -or $op_kind -match '[\\*]') {
    [Console]::Out.Write("ERROR: invalid op_kind: $op_kind`n")
    exit 1
}

# Validate record_filename: reject '..', '/', '\'
if ($record_filename -match '\.\.' -or $record_filename -match '[/\\]') {
    [Console]::Out.Write("ERROR: invalid record_filename: $record_filename`n")
    exit 1
}

# Step 1: Resolve repo root from the FIRST file
$first_file = $files[0]
$target_dir = Split-Path -Parent ([System.IO.Path]::GetFullPath($first_file))
$repo_root = (& git -C $target_dir rev-parse --show-toplevel 2>$null)
if (-not $repo_root) {
    $repo_root = $target_dir
    [Console]::Error.WriteLine("WARN: not in a git repo; falling back to file's parent dir as repo_root: $repo_root")
}
$repo_root = $repo_root.TrimEnd('/', '\')
$repo_root_fwd = $repo_root -replace '\\', '/'

# Step 2: For each file, resolve absolute path, compute repo-relative path, compute blob hash
$pairs = @()

foreach ($file_path in $files) {
    # Resolve to absolute path
    $abs_path = [System.IO.Path]::GetFullPath($file_path)
    # Normalize to forward slashes
    $abs_fwd = $abs_path -replace '\\', '/'

    # Compute repo-relative path
    if ($abs_fwd.StartsWith($repo_root_fwd + '/')) {
        $rel_path = $abs_fwd.Substring($repo_root_fwd.Length + 1)
    } else {
        $rel_path = $abs_fwd
    }
    # Strip any leading slash just in case
    $rel_path = $rel_path.TrimStart('/')

    # Compute blob hash
    $blob_hash = (& git hash-object $abs_path 2>$null)
    if ($LASTEXITCODE -ne 0 -or -not $blob_hash) {
        [Console]::Out.Write("ERROR: missing: $rel_path`n")
        exit 1
    }
    $blob_hash = $blob_hash.Trim()

    $pairs += "$rel_path $blob_hash"
}

# Step 3: Sort pairs lexically by repo-relative path (ascending, byte-order).
# `Sort-Object` defaults to current-culture collation (case-insensitive); bash
# `sort` defaults to LC_COLLATE / byte-order. Use ordinal-case-sensitive sort
# to match bash byte-order behaviour exactly.
$sorted_pairs = $pairs | Sort-Object -CaseSensitive -Culture ''

# Step 4: Build manifest text with explicit LF line endings (no CRLF)
$manifest_text = ''
foreach ($pair in $sorted_pairs) {
    $manifest_text += "$pair`n"
}

# Step 5: Compute manifest hash via git hash-object on a temp file
# Pipe-to-stdin in PowerShell mangles line endings (CRLF leak); write the exact
# bytes we want to a temp file and hash the file directly. Cross-shell parity
# with bash's `printf '%s' "$text" | git hash-object --stdin` requires the
# byte-for-byte LF-terminated content.
$bytes = [System.Text.Encoding]::UTF8.GetBytes($manifest_text)
$tmp_file = [System.IO.Path]::GetTempFileName()
try {
    [System.IO.File]::WriteAllBytes($tmp_file, $bytes)
    $manifest_hash = (& git hash-object $tmp_file 2>$null)
    if ($LASTEXITCODE -ne 0 -or -not $manifest_hash) {
        [Console]::Out.Write("ERROR: git hash-object failed to compute manifest hash`n")
        exit 1
    }
    $manifest_hash = $manifest_hash.Trim()
} finally {
    Remove-Item -LiteralPath $tmp_file -ErrorAction SilentlyContinue
}

# Step 6: Construct cache path
$shard = $manifest_hash.Substring(0, 2)
$cache_path = "$repo_root_fwd/.hash-record/$shard/$manifest_hash/$op_kind/$record_filename"

# Step 7: Test whether cache file exists
if (Test-Path -LiteralPath $cache_path -PathType Leaf) {
    [Console]::Out.Write("HIT: $cache_path`n")
    exit 0
}

[Console]::Out.Write("MISS: $cache_path`n")
exit 0
