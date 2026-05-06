# rekey.ps1 — hash-record re-key after file content change
#Requires -Version 7
# Usage (per-file): rekey.ps1 <file_path> <op_kind> <record_filename> [source_hash]
# Usage (folder):   rekey.ps1 <folder_path> [--include <glob>] [--exclude <glob>] [--dry-run] [--manifests <bool>]
# Outputs one of:
#   REKEYED: <new_abs_path>
#   CURRENT: <abs_path>
#   NOT_FOUND: no record for <op_kind>/<record_filename>   (per-file)
#   NOT_FOUND: no record for <file-rel-path>               (folder)
#   AMBIGUOUS: <n> records found -- manual resolution required
#   MANIFEST_UPDATED: <manifest-path>:<entry-id>
#   SUMMARY: rekeyed=<n> current=<n> manifest_updated=<n> not_found=<n> errors=<n>
#   ERROR: <reason>

$ErrorActionPreference = 'Continue'

# ---------------------------------------------------------------------------
# Help text
# ---------------------------------------------------------------------------
function Write-Help {
    [Console]::Out.Write(@"
Usage (per-file): rekey <file_path> <op_kind> <record_filename> [source_hash]
Usage (folder):   rekey <folder_path> [--include <glob>] [--exclude <glob>] [--dry-run] [--manifests <bool>]

Re-key hash-record entries after source file content changes.

Per-file arguments:
  file_path        Absolute path to the changed file (new content, not yet committed).
  op_kind          Operation kind, e.g. "markdown-hygiene" or "skill-auditing/v2". May contain /.
  record_filename  Leaf filename, e.g. "claude-haiku.md". No path separators or ..
  source_hash      (Optional) The known old content hash. Skips full-tree search when provided.

Folder-mode flags (first arg is an existing directory):
  --include <glob>    Restrict scope to matching files (repeatable; default: all).
  --exclude <glob>    Skip matching files (repeatable; default: none).
  --dry-run           Report changes without performing git mv or writes.
  --manifests <bool>  Include manifest entries (default: true).

Per-file output (stdout, one line):
  REKEYED: <abs-path>   Record moved to new hash path.
  CURRENT: <abs-path>   Old hash == new hash. No move needed.
  NOT_FOUND: ...        No record exists for this op_kind/record_filename.
  AMBIGUOUS: <n> ...    Multiple records found -- manual resolution required.
  ERROR: <reason>       Argument or runtime error.

Folder-mode output (stdout, one line per record, then summary):
  REKEYED: <abs-path>
  CURRENT: <abs-path>
  NOT_FOUND: no record for <file-rel-path>
  MANIFEST_UPDATED: <manifest-path>:<entry-id>
  ERROR: <reason>
  SUMMARY: rekeyed=<n> current=<n> manifest_updated=<n> not_found=<n> errors=<n>

Exit codes:
  0   Success (or --dry-run with no errors).
  1   Per-record error (attempts all before exiting).
  2   Invocation error (bad path, bad flags).
"@)
}

# ---------------------------------------------------------------------------
# Helper: normalize path to forward slashes, no trailing slash
# ---------------------------------------------------------------------------
function ConvertTo-ForwardSlash ([string]$p) {
    ($p -replace '\\', '/').TrimEnd('/')
}

# ---------------------------------------------------------------------------
# Helper: extract file_path / file_paths from YAML frontmatter of a record
# Returns an array of repo-relative paths (strings)
# ---------------------------------------------------------------------------
function Get-FrontmatterPaths ([string]$RecordFile) {
    $paths = [System.Collections.Generic.List[string]]::new()
    $pastOpen = $false
    $collectingList = $false
    foreach ($line in [System.IO.File]::ReadLines($RecordFile)) {
        $line = $line.TrimEnd("`r")
        if (-not $pastOpen) {
            if ($line -eq '---') { $pastOpen = $true }
            continue
        }
        if ($line -eq '---') { break }
        if ($line -match '^file_path:\s+(.+)$') {
            $collectingList = $false
            $paths.Add($Matches[1].Trim())
        } elseif ($line -match '^file_paths:\s*$') {
            $collectingList = $true
        } elseif ($collectingList -and $line -match '^\s+-\s+(.+)$') {
            $paths.Add($Matches[1].Trim())
        } elseif ($line -match '^[a-z_]+:') {
            $collectingList = $false
        }
    }
    return $paths
}

# ---------------------------------------------------------------------------
# Helper: glob match (PowerShell -like operator)
# ---------------------------------------------------------------------------
function Test-GlobMatch ([string]$Path, [string[]]$Globs) {
    foreach ($g in $Globs) {
        if ($Path -like $g) { return $true }
    }
    return $false
}

# ---------------------------------------------------------------------------
# Helper: compute manifest hash for a multi-file record
# git-blob hash (SHA-1, 40-char hex) of the manifest string (sorted
# "<blob_hash> <path>`n" lines for all files in file_paths). Matches
# `hash-record-manifest/manifest.ps1` semantics: write manifest text to a
# temp file, run `git hash-object` on it. Using SHA-1-via-git-hash-object
# ensures the path computed here equals the path the result tools compute
# on the same content. Returns 40-char hex, or $null on error.
# ---------------------------------------------------------------------------
function Get-ManifestHash ([string]$RecordFile, [string]$RepoRoot) {
    $paths = Get-FrontmatterPaths $RecordFile
    if ($paths.Count -eq 0) { return $null }

    # Build pairs first (path + space + blob hash), then sort the FULL pair
    # string. This mirrors `hash-record-manifest/manifest.ps1` lines 99 +
    # 106 exactly. Sorting only by path key produces a different ordering
    # in edge cases and yields an incompatible hash.
    $pairs = @()
    foreach ($fpath in $paths) {
        $absPath = "$RepoRoot/$fpath"
        $blobHash = (& git hash-object $absPath 2>$null)
        if ($LASTEXITCODE -ne 0 -or -not $blobHash) { return $null }
        $blobHash = $blobHash.Trim()
        # Format MUST match manifest.ps1: `<path> <blob_hash>` (path first).
        $pairs += "$fpath $blobHash"
    }

    # Same sort as manifest.ps1: ordinal, case-sensitive, byte-order.
    $sortedPairs = $pairs | Sort-Object -CaseSensitive -Culture ''

    # Build manifest text with explicit LF line endings (matches manifest.ps1).
    $manifestStr = ''
    foreach ($pair in $sortedPairs) {
        $manifestStr += "$pair`n"
    }

    # Write manifest text to a temp file and run `git hash-object` — exact
    # mirror of `hash-record-manifest/manifest.ps1` (lines 119-128). Use
    # the same byte path: `Encoding.UTF8.GetBytes` + `WriteAllBytes` to
    # avoid BOM/line-ending drift that can shift the hash.
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($manifestStr)
    $tmpFile = [System.IO.Path]::GetTempFileName()
    try {
        [System.IO.File]::WriteAllBytes($tmpFile, $bytes)
        $manifestHash = (& git hash-object $tmpFile 2>$null)
        if ($LASTEXITCODE -ne 0 -or -not $manifestHash) { return $null }
        return $manifestHash.Trim()
    } finally {
        if (Test-Path -LiteralPath $tmpFile) { Remove-Item -LiteralPath $tmpFile -Force }
    }
}

# ---------------------------------------------------------------------------
# Parse args manually to support repeatable flags
# ---------------------------------------------------------------------------
$args_list = [System.Collections.Generic.List[string]]::new()
foreach ($a in $args) { $args_list.Add($a) }

if ($args_list.Count -eq 0) {
    [Console]::Out.Write("ERROR: missing arguments -- expected <file_path> <op_kind> <record_filename> or <folder_path>`n")
    exit 2
}

$firstArg = $args_list[0]

# Handle --help / -h at top level
if ($firstArg -eq '--help' -or $firstArg -eq '-h') {
    Write-Help
    exit 0
}

# ---------------------------------------------------------------------------
# Detect mode: folder vs per-file
# ---------------------------------------------------------------------------
if (Test-Path -LiteralPath $firstArg -PathType Container) {
    # =======================================================================
    # FOLDER MODE
    # =======================================================================
    $folderPath = ConvertTo-ForwardSlash $firstArg
    $includes   = [System.Collections.Generic.List[string]]::new()
    $excludes   = [System.Collections.Generic.List[string]]::new()
    $dryRun     = $false
    $doManifests = $true

    $i = 1
    while ($i -lt $args_list.Count) {
        $flag = $args_list[$i]
        switch ($flag) {
            '--include' {
                if ($i + 1 -ge $args_list.Count) {
                    [Console]::Out.Write("ERROR: --include requires a value`n")
                    exit 2
                }
                $includes.Add($args_list[$i + 1])
                $i += 2
            }
            '--exclude' {
                if ($i + 1 -ge $args_list.Count) {
                    [Console]::Out.Write("ERROR: --exclude requires a value`n")
                    exit 2
                }
                $excludes.Add($args_list[$i + 1])
                $i += 2
            }
            '--dry-run' {
                $dryRun = $true
                $i++
            }
            '--manifests' {
                if ($i + 1 -ge $args_list.Count) {
                    [Console]::Out.Write("ERROR: --manifests requires a value (true|false)`n")
                    exit 2
                }
                $mv = $args_list[$i + 1].ToLower()
                if ($mv -eq 'true' -or $mv -eq '1' -or $mv -eq 'yes') {
                    $doManifests = $true
                } elseif ($mv -eq 'false' -or $mv -eq '0' -or $mv -eq 'no') {
                    $doManifests = $false
                } else {
                    [Console]::Out.Write("ERROR: --manifests value must be true or false, got: $($args_list[$i + 1])`n")
                    exit 2
                }
                $i += 2
            }
            { $_ -eq '--help' -or $_ -eq '-h' } {
                Write-Help
                exit 0
            }
            default {
                [Console]::Out.Write("ERROR: unknown flag: $flag`n")
                exit 2
            }
        }
    }

    # Resolve repo root
    $repoRoot = (& git -C $folderPath rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -ne 0 -or -not $repoRoot) {
        $repoRoot = $folderPath
        [Console]::Error.WriteLine("WARN: not in a git repo; falling back to folder_path as repo_root: $repoRoot")
    }
    $repoRoot = ConvertTo-ForwardSlash $repoRoot

    $hashRecordRoot = "$repoRoot/.hash-record"

    # -----------------------------------------------------------------------
    # Load all records from .hash-record/ into a list
    # Each entry: [rec_path_fwd, rec_hash, op_kind, rec_filename]
    # -----------------------------------------------------------------------
    $allRecords = [System.Collections.Generic.List[object]]::new()
    if (Test-Path -LiteralPath $hashRecordRoot -PathType Container) {
        Get-ChildItem -Path $hashRecordRoot -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
            $recPathFwd = ConvertTo-ForwardSlash $_.FullName
            $afterRoot = $recPathFwd.Substring($hashRecordRoot.Length).TrimStart('/')
            # afterRoot = <shard>/<hash>/<op_kind...>/<filename>
            $parts = $afterRoot -split '/', 3   # [shard, hash, rest]
            if ($parts.Count -lt 3) { return }
            $recHash     = $parts[1]
            $rest        = $parts[2]            # <op_kind...>/<filename>
            $lastSlash   = $rest.LastIndexOf('/')
            if ($lastSlash -lt 0) { return }
            $recOpKind   = $rest.Substring(0, $lastSlash)
            $recFilename = $rest.Substring($lastSlash + 1)
            $allRecords.Add([PSCustomObject]@{
                Path     = $recPathFwd
                Hash     = $recHash
                OpKind   = $recOpKind
                Filename = $recFilename
            })
        }
    }

    # Counters
    $cntRekeyed         = 0
    $cntCurrent         = 0
    $cntManifestUpdated = 0
    $cntNotFound        = 0
    $cntErrors          = 0
    $hadError           = $false

    # -----------------------------------------------------------------------
    # Collect files under folder_path, sorted
    # -----------------------------------------------------------------------
    $files = Get-ChildItem -Path $folderPath -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[/\\]\.git[/\\]' } |
        Sort-Object FullName -CaseSensitive

    # Deferred multi-file records: hashtable rec.Path -> rec object
    $deferredManifests = [System.Collections.Generic.Dictionary[string,object]]::new()

    foreach ($fileInfo in $files) {
        $fileAbsFwd = ConvertTo-ForwardSlash $fileInfo.FullName

        # Compute repo-relative path
        if ($fileAbsFwd.StartsWith($repoRoot + '/')) {
            $fileRel = $fileAbsFwd.Substring($repoRoot.Length + 1)
        } else {
            $fileRel = $fileAbsFwd
        }

        # Compute folder-relative path for include/exclude matching
        if ($fileAbsFwd.StartsWith($folderPath + '/')) {
            $fileFolderRel = $fileAbsFwd.Substring($folderPath.Length + 1)
        } else {
            $fileFolderRel = $fileRel
        }

        # Apply include filter
        if ($includes.Count -gt 0) {
            if (-not (Test-GlobMatch $fileFolderRel $includes)) { continue }
        }

        # Apply exclude filter
        if ($excludes.Count -gt 0) {
            if (Test-GlobMatch $fileFolderRel $excludes) { continue }
        }

        # Compute current blob hash
        $currentHash = (& git hash-object $fileInfo.FullName 2>$null)
        if ($LASTEXITCODE -ne 0 -or -not $currentHash) {
            [Console]::Out.Write("ERROR: git hash-object failed for: $fileRel`n")
            $cntErrors++
            $hadError = $true
            continue
        }
        $currentHash  = $currentHash.Trim()
        $currentShard = $currentHash.Substring(0, 2)

        # Find records referencing this file
        $fileRecordsFound = 0

        foreach ($rec in $allRecords) {
            # Check if this record's frontmatter references fileRel
            $referencesFile = $false
            try {
                $fmPaths = Get-FrontmatterPaths $rec.Path
                foreach ($fp in $fmPaths) {
                    $fp = $fp.Trim()
                    if ($fp -eq $fileRel) {
                        $referencesFile = $true
                        break
                    }
                }
            } catch {
                # Skip unreadable records
                continue
            }
            if (-not $referencesFile) { continue }

            $fileRecordsFound++

            # Detect single-file vs multi-file record
            $recAllPaths = Get-FrontmatterPaths $rec.Path
            $pathCount = $recAllPaths.Count

            if ($pathCount -le 1) {
                # Single-file record: rekey based on this file's current blob hash
                if ($rec.Hash -eq $currentHash) {
                    [Console]::Out.Write("CURRENT: $($rec.Path)`n")
                    $cntCurrent++
                } else {
                    $newRecordDir  = "$hashRecordRoot/$currentShard/$currentHash/$($rec.OpKind)"
                    $newRecordPath = "$newRecordDir/$($rec.Filename)"

                    if ($dryRun) {
                        [Console]::Out.Write("REKEYED: $newRecordPath`n")
                        $cntRekeyed++
                    } else {
                        try {
                            New-Item -ItemType Directory -Force -Path $newRecordDir -ErrorAction Stop | Out-Null
                        } catch {
                            [Console]::Out.Write("ERROR: mkdir failed for: $newRecordDir`n")
                            $cntErrors++
                            $hadError = $true
                            continue
                        }

                        $oldRel = $rec.Path.Substring($repoRoot.Length).TrimStart('/')
                        $newRel = $newRecordPath.Substring($repoRoot.Length).TrimStart('/')

                        & git -C $repoRoot mv $oldRel $newRel 2>$null
                        if ($LASTEXITCODE -ne 0) {
                            [Console]::Out.Write("ERROR: git mv failed: $oldRel -> $newRel`n")
                            $cntErrors++
                            $hadError = $true
                            continue
                        }

                        [Console]::Out.Write("REKEYED: $newRecordPath`n")
                        $cntRekeyed++
                        $rec.Path = $newRecordPath
                        $rec.Hash = $currentHash
                    }
                }
            } else {
                # Multi-file record: defer to manifest-hash processing after per-file loop
                if (-not $deferredManifests.ContainsKey($rec.Path)) {
                    $deferredManifests[$rec.Path] = $rec
                }
            }
        }

        if ($fileRecordsFound -eq 0) {
            [Console]::Out.Write("NOT_FOUND: no record for $fileRel`n")
            $cntNotFound++
        }
    }

    # ---------------------------------------------------------------------------
    # Process deferred multi-file (manifest) records
    # ---------------------------------------------------------------------------
    if ($doManifests -and $deferredManifests.Count -gt 0) {
        foreach ($recPath in @($deferredManifests.Keys)) {
            $rec = $deferredManifests[$recPath]

            $manifestHash = Get-ManifestHash $recPath $repoRoot
            if (-not $manifestHash) {
                [Console]::Out.Write("ERROR: manifest hash computation failed for: $recPath`n")
                $cntErrors++
                $hadError = $true
                continue
            }
            $manifestShard = $manifestHash.Substring(0, 2)

            if ($rec.Hash -eq $manifestHash) {
                [Console]::Out.Write("CURRENT: $recPath`n")
                $cntCurrent++
            } else {
                $newRecordDir  = "$hashRecordRoot/$manifestShard/$manifestHash/$($rec.OpKind)"
                $newRecordPath = "$newRecordDir/$($rec.Filename)"

                if ($dryRun) {
                    [Console]::Out.Write("REKEYED: $newRecordPath`n")
                    $cntRekeyed++
                } else {
                    try {
                        New-Item -ItemType Directory -Force -Path $newRecordDir -ErrorAction Stop | Out-Null
                    } catch {
                        [Console]::Out.Write("ERROR: mkdir failed for: $newRecordDir`n")
                        $cntErrors++
                        $hadError = $true
                        continue
                    }

                    $oldRel = $recPath.Substring($repoRoot.Length).TrimStart('/')
                    $newRel = $newRecordPath.Substring($repoRoot.Length).TrimStart('/')

                    & git -C $repoRoot mv $oldRel $newRel 2>$null
                    if ($LASTEXITCODE -ne 0) {
                        [Console]::Out.Write("ERROR: git mv failed: $oldRel -> $newRel`n")
                        $cntErrors++
                        $hadError = $true
                        continue
                    }

                    [Console]::Out.Write("REKEYED: $newRecordPath`n")
                    $cntRekeyed++
                }
            }
        }
    }

    [Console]::Out.Write("SUMMARY: rekeyed=$cntRekeyed current=$cntCurrent manifest_updated=$cntManifestUpdated not_found=$cntNotFound errors=$cntErrors`n")

    if ($hadError) { exit 1 }
    exit 0

} else {
    # =======================================================================
    # PER-FILE MODE (original, unchanged)
    # =======================================================================

    $file_path       = $args_list.Count -gt 0 ? $args_list[0] : ""
    $op_kind         = $args_list.Count -gt 1 ? $args_list[1] : ""
    $record_filename = $args_list.Count -gt 2 ? $args_list[2] : ""
    $SourceHash      = $args_list.Count -gt 3 ? $args_list[3] : ""

    if (-not $file_path -or -not $op_kind -or -not $record_filename) {
        [Console]::Out.Write("ERROR: missing arguments -- expected <file_path> <op_kind> <record_filename>`n")
        exit 2
    }

    if ($op_kind -match '\.\.' -or $op_kind -match '[\\]') {
        [Console]::Out.Write("ERROR: invalid op_kind: $op_kind`n")
        exit 1
    }

    if ($record_filename -match '\.\.' -or $record_filename -match '[/\\]') {
        [Console]::Out.Write("ERROR: invalid record_filename: $record_filename`n")
        exit 1
    }

    if ($SourceHash -and $SourceHash -notmatch '^[0-9a-f]{40}$') {
        [Console]::Out.Write("ERROR: invalid source_hash: $SourceHash`n")
        exit 1
    }

    $target_dir = Split-Path -Parent $file_path
    $repo_root = (& git -C $target_dir rev-parse --show-toplevel 2>$null)
    if (-not $repo_root) {
        $repo_root = $target_dir
        [Console]::Error.WriteLine("WARN: not in a git repo; falling back to file's parent dir as repo_root: $repo_root")
    }
    $repo_root = $repo_root.TrimEnd('/', '\') -replace '\\', '/'

    $new_hash = (& git hash-object $file_path 2>$null)
    if ($LASTEXITCODE -ne 0 -or -not $new_hash) {
        [Console]::Out.Write("ERROR: git hash-object failed for: $file_path`n")
        exit 1
    }
    $new_hash = $new_hash.Trim()
    $new_shard = $new_hash.Substring(0, 2)

    $hash_record_root = "$repo_root/.hash-record"

    if (-not (Test-Path $hash_record_root -PathType Container)) {
        [Console]::Out.Write("NOT_FOUND: no record for $op_kind/$record_filename`n")
        exit 0
    }

    $op_kind_path = $op_kind -replace '/', [IO.Path]::DirectorySeparatorChar

    if ($SourceHash -ne "") {
        $source_shard = $SourceHash.Substring(0, 2)
        $candidate_dir = "$hash_record_root/$source_shard/$SourceHash/$op_kind"
        $candidate_path = "$candidate_dir/$record_filename"
        $candidate_path_norm = $candidate_path -replace '\\', '/'
        if (-not (Test-Path -LiteralPath $candidate_path -PathType Leaf)) {
            [Console]::Out.Write("NOT_FOUND: no record for $op_kind/$record_filename at $SourceHash`n")
            exit 0
        }
        $old_record = [PSCustomObject]@{
            Hash      = $SourceHash
            Shard     = $source_shard
            Path      = $candidate_path_norm
            ParentDir = ($candidate_dir -replace '\\', '/')
        }
    } else {
        $found = [System.Collections.Generic.List[object]]::new()

        Get-ChildItem -Path $hash_record_root -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $shard_dir = $_
            Get-ChildItem -Path $shard_dir.FullName -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                $hash_dir = $_
                $candidate_dir = Join-Path $hash_dir.FullName $op_kind_path
                $candidate = Join-Path $candidate_dir $record_filename
                if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                    $found.Add([PSCustomObject]@{
                        Hash      = $hash_dir.Name
                        Shard     = $shard_dir.Name
                        Path      = ($candidate -replace '\\', '/')
                        ParentDir = ($candidate_dir -replace '\\', '/')
                    })
                }
            }
        }

        if ($found.Count -eq 0) {
            [Console]::Out.Write("NOT_FOUND: no record for $op_kind/$record_filename`n")
            exit 0
        }

        if ($found.Count -gt 1) {
            [Console]::Out.Write("AMBIGUOUS: $($found.Count) records found -- manual resolution required`n")
            exit 1
        }

        $old_record = $found[0]
    }

    if ($old_record.Hash -eq $new_hash) {
        [Console]::Out.Write("CURRENT: $($old_record.Path)`n")
        exit 0
    }

    $new_record_dir  = "$hash_record_root/$new_shard/$new_hash/$op_kind"
    $new_record_path = "$new_record_dir/$record_filename"

    New-Item -ItemType Directory -Force -Path $new_record_dir | Out-Null

    $old_rel = $old_record.Path.Substring($repo_root.Length).TrimStart('/')
    $new_rel = $new_record_path.Substring($repo_root.Length).TrimStart('/')

    & git -C $repo_root mv $old_rel $new_rel
    if ($LASTEXITCODE -ne 0) {
        [Console]::Out.Write("ERROR: git mv failed: $old_rel -> $new_rel`n")
        exit 1
    }

    [Console]::Out.Write("REKEYED: $new_record_path`n")
    exit 0
}
