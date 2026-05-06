#!/usr/bin/env bash
# prune.sh — hash-record orphan pruner
# Usage: prune.sh <repo_root> [--target <glob>] [--dry-run] [--limit <N>]
# Prunes orphaned hash directories from <repo_root>/.hash-record/.
set -e

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  cat <<'USAGE'
Usage: prune.sh <repo_root> [--target <glob>] [--dry-run] [--limit <N>]

Prune orphaned entries from <repo_root>/.hash-record/.
A record is orphaned when no current file in the repo hashes to its key.

Arguments:
  repo_root       Absolute path to the repository root.
                  Must not contain '..' or shell metacharacters.

Flags:
  --target <glob> Relative glob pattern matched against repo-relative paths.
                  Only hash directories with a matching associated path are
                  candidates. Must not be an absolute path.
  --dry-run       Report orphan count without deleting.
  --limit <N>     Cap deletions at N per invocation (non-negative integer).
  --help/-h       Print this help and exit 0.

Output (stdout, one line):
  CLEAN           No orphans found.
  pruned: <N>     N orphans deleted.
  dry-run: <N>    Dry-run mode; N would be deleted.
  ERROR: <reason> Pre-execution failure.

Exit codes:
  0  Success.
  1  Error.
USAGE
  exit 0
fi

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
REPO_ROOT=""
DRY_RUN=0
LIMIT=-1
TARGET=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --target)
      if [ -z "$2" ]; then
        echo "ERROR: --target requires a value"
        exit 1
      fi
      TARGET="$2"
      shift 2
      ;;
    --limit)
      if [ -z "$2" ]; then
        echo "ERROR: --limit requires a value"
        exit 1
      fi
      case "$2" in
        ''|*[!0-9]*)
          echo "ERROR: --limit must be a non-negative integer, got: $2"
          exit 1
          ;;
      esac
      LIMIT="$2"
      shift 2
      ;;
    --help|-h)
      shift
      ;;
    --*)
      echo "ERROR: unknown flag: $1"
      exit 1
      ;;
    *)
      if [ -n "$REPO_ROOT" ]; then
        echo "ERROR: unexpected argument: $1"
        exit 1
      fi
      REPO_ROOT="$1"
      shift
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Validate repo_root
# ---------------------------------------------------------------------------
if [ -z "$REPO_ROOT" ]; then
  echo "ERROR: missing required argument: repo_root"
  exit 1
fi

# Reject '..' path traversal
case "$REPO_ROOT" in
  *..*) echo "ERROR: repo_root must not contain '..': $REPO_ROOT"; exit 1 ;;
esac

# Reject shell metacharacters
case "$REPO_ROOT" in
  *";"*|*"|"*|*"&"*|*'$'*|*">"*|*"<"*|*'`'*|*"("*|*")"*|*"{"*|*"}"*)
    echo "ERROR: repo_root contains shell metacharacters: $REPO_ROOT"
    exit 1
    ;;
esac

# Require absolute path
case "$REPO_ROOT" in
  /*)        ;;  # POSIX absolute
  [A-Za-z]:*) ;;  # Windows drive letter (Git Bash)
  *)
    echo "ERROR: repo_root must be an absolute path: $REPO_ROOT"
    exit 1
    ;;
esac

# Validate --target: must not be an absolute path
if [ -n "$TARGET" ]; then
  case "$TARGET" in
    /*|[A-Za-z]:*)
      echo "ERROR: --target must be a relative glob pattern: $TARGET"
      exit 1
      ;;
  esac
fi

HASH_RECORD_DIR="${REPO_ROOT}/.hash-record"

# ---------------------------------------------------------------------------
# CLEAN exit if .hash-record/ is absent
# ---------------------------------------------------------------------------
if [ ! -d "$HASH_RECORD_DIR" ]; then
  echo "CLEAN"
  exit 0
fi

# ---------------------------------------------------------------------------
# Temp file setup — cleaned up on exit
# ---------------------------------------------------------------------------
VALID_HASHES_FILE=""
SUBMODULE_PATHS_FILE=""
ORPHANS_FILE=""

cleanup() {
  [ -n "$VALID_HASHES_FILE"  ] && rm -f "$VALID_HASHES_FILE"
  [ -n "$SUBMODULE_PATHS_FILE" ] && rm -f "$SUBMODULE_PATHS_FILE"
  [ -n "$ORPHANS_FILE"       ] && rm -f "$ORPHANS_FILE"
}
trap cleanup EXIT

VALID_HASHES_FILE=$(mktemp)   || { echo "ERROR: could not create temp file"; exit 1; }
SUBMODULE_PATHS_FILE=$(mktemp) || { echo "ERROR: could not create temp file"; exit 1; }
ORPHANS_FILE=$(mktemp)         || { echo "ERROR: could not create temp file"; exit 1; }

# ---------------------------------------------------------------------------
# Collect submodule paths (excluded from hash scan)
# ---------------------------------------------------------------------------
if [ -f "${REPO_ROOT}/.gitmodules" ]; then
  git config -f "${REPO_ROOT}/.gitmodules" --get-regexp '^submodule\..*\.path$' 2>/dev/null \
    | awk '{print $2}' > "$SUBMODULE_PATHS_FILE" || true
fi

# ---------------------------------------------------------------------------
# Build valid-hash set (for non-manifest hash dirs)
# Compute atomically before any deletion begins.
# ---------------------------------------------------------------------------
while IFS= read -r -d '' rel_path; do
  [ -z "$rel_path" ] && continue

  # Skip .worktrees/ paths
  case "$rel_path" in .worktrees/*) continue ;; esac

  # Skip submodule paths
  if [ -s "$SUBMODULE_PATHS_FILE" ]; then
    skip=0
    while IFS= read -r sm_path || [ -n "$sm_path" ]; do
      [ -z "$sm_path" ] && continue
      case "$rel_path" in
        "$sm_path"|"$sm_path"/*) skip=1; break ;;
      esac
    done < "$SUBMODULE_PATHS_FILE"
    [ "$skip" = "1" ] && continue
  fi

  abs_path="${REPO_ROOT}/${rel_path}"
  [ -f "$abs_path" ] || continue

  h=$(git hash-object "$abs_path" 2>/dev/null) || continue
  [ -n "$h" ] && printf '%s\n' "$h" >> "$VALID_HASHES_FILE"

done < <(git -C "$REPO_ROOT" ls-files -z --cached --others --exclude-standard 2>/dev/null)

# ---------------------------------------------------------------------------
# Manifest validity check
# Reads manifest.yaml file_paths, re-derives the manifest hash, compares to
# the hash directory name. Outputs "VALID" or "ORPHANED"; always exits 0.
# ---------------------------------------------------------------------------
check_manifest() {
  local repo_root="$1"
  local hash_name="$2"
  local manifest="$3"

  # Parse file_paths list from YAML (lines matching "  - <path>")
  local file_paths=()
  local in_fp=0
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      file_paths:*) in_fp=1; continue ;;
    esac
    if [ "$in_fp" = "1" ]; then
      if [[ "$line" =~ ^[[:space:]]*-[[:space:]]+(.+) ]]; then
        local fpath="${BASH_REMATCH[1]%$'\r'}"  # strip trailing CR
        [ -n "$fpath" ] && file_paths+=("$fpath")
      elif [[ "$line" =~ ^[^[:space:]] ]]; then
        break  # non-indented line ends the file_paths block
      fi
    fi
  done < "$manifest"

  if [ "${#file_paths[@]}" -eq 0 ]; then
    echo "ORPHANED"; return 0
  fi

  # Build (path hash) pairs; bail to ORPHANED if any file is missing or unhashable
  local pairs=()
  local fpath abs h
  for fpath in "${file_paths[@]}"; do
    abs="${repo_root}/${fpath}"
    if [ ! -f "$abs" ]; then echo "ORPHANED"; return 0; fi
    h=$(git hash-object "$abs" 2>/dev/null) || { echo "ORPHANED"; return 0; }
    [ -z "$h" ] && { echo "ORPHANED"; return 0; }
    pairs+=("${fpath} ${h}")
  done

  # Sort lexically by path (byte-order, matching manifest.sh) and build manifest text
  local manifest_text=""
  while IFS= read -r pair || [ -n "$pair" ]; do
    manifest_text="${manifest_text}${pair}"$'\n'
  done < <(LC_ALL=C printf '%s\n' "${pairs[@]}" | LC_ALL=C sort)

  [ -z "$manifest_text" ] && { echo "ORPHANED"; return 0; }

  # Hash the manifest text (byte-identical to manifest.sh / manifest.ps1)
  local computed_hash
  computed_hash=$(printf '%s' "$manifest_text" | git hash-object --stdin 2>/dev/null) \
    || { echo "ORPHANED"; return 0; }

  [ "$computed_hash" = "$hash_name" ] && echo "VALID" || echo "ORPHANED"
  return 0
}

# ---------------------------------------------------------------------------
# Glob match helper
# Usage: glob_match <path> <glob>
# Returns 0 (match) or 1 (no match). Supports * ? and ** (any path depth).
# Matching is done against repo-relative paths (no leading slash).
# ---------------------------------------------------------------------------
glob_match() {
  local path="$1"
  local glob="$2"

  # Use bash's extglob + recursive case matching via a recursive helper.
  # Strategy: convert ** to a sentinel, split on /, match segment by segment.
  # Simpler approach: use Python-free fnmatch via a recursive bash function.

  # Expand ** by trying all possible depths (0..N path segments).
  # We do this by converting the glob to a regex in pure bash.
  local regex
  regex=$(printf '%s' "$glob" | sed \
    -e 's/[.^$+{}|()\\]/\\&/g' \
    -e 's/\*\*/.*/g' \
    -e 's/\*\([^.]*\)/[^\/]*/g' \
    -e 's/?/[^\/]/g')
  # Anchor full path
  regex="^${regex}$"
  [[ "$path" =~ $regex ]]
}

# ---------------------------------------------------------------------------
# Target match helper
# Returns 0 if the hash directory has at least one associated path matching
# $TARGET, or if TARGET is empty (no filter). Returns 1 to skip.
# ---------------------------------------------------------------------------
check_target_match() {
  local hash_dir="$1"
  local glob="$2"

  [ -z "$glob" ] && return 0

  local manifest="${hash_dir}/manifest.yaml"
  if [ -f "$manifest" ]; then
    # Manifest record: check file_paths list
    local in_fp=0
    while IFS= read -r line || [ -n "$line" ]; do
      case "$line" in file_paths:*) in_fp=1; continue ;; esac
      if [ "$in_fp" = "1" ]; then
        if [[ "$line" =~ ^[[:space:]]*-[[:space:]]+(.+) ]]; then
          local fpath="${BASH_REMATCH[1]%$'\r'}"
          if [ -n "$fpath" ] && glob_match "$fpath" "$glob"; then
            return 0
          fi
        elif [[ "$line" =~ ^[^[:space:]] ]]; then
          break
        fi
      fi
    done < "$manifest"
    return 1
  fi

  # Non-manifest: find first readable leaf .md and check file_path frontmatter
  local leaf
  while IFS= read -r -d '' leaf; do
    local in_front=0 front_done=0
    while IFS= read -r line || [ -n "$line" ]; do
      if [ "$in_front" = "0" ] && [[ "$line" =~ ^--- ]]; then
        in_front=1; continue
      fi
      if [ "$in_front" = "1" ] && [ "$front_done" = "0" ]; then
        if [[ "$line" =~ ^--- ]]; then front_done=1; break; fi
        if [[ "$line" =~ ^file_path:[[:space:]]*(.+) ]]; then
          local fpath="${BASH_REMATCH[1]%$'\r'}"
          fpath="${fpath## }" ; fpath="${fpath%% }"
          if [ -n "$fpath" ] && glob_match "$fpath" "$glob"; then
            return 0
          fi
          break  # file_path found; only one per record
        fi
      fi
    done < "$leaf"
  done < <(find "$hash_dir" -name '*.md' -type f -print0 2>/dev/null)
  return 1
}

# ---------------------------------------------------------------------------
# Walk .hash-record/ two levels deep and classify each hash directory
# ---------------------------------------------------------------------------
while IFS= read -r -d '' shard_dir; do
  shard_name=$(basename "$shard_dir")
  # Skip dot-prefixed admin directories
  case "$shard_name" in .*) continue ;; esac

  while IFS= read -r -d '' hash_dir; do
    hash_name=$(basename "$hash_dir")
    manifest="${hash_dir}/manifest.yaml"
    result=""

    # Apply --target filter before validity checking
    if [ -n "$TARGET" ]; then
      check_target_match "$hash_dir" "$TARGET" || continue
    fi

    if [ -f "$manifest" ]; then
      # Manifest strategy: re-derive the manifest hash and compare
      result=$(check_manifest "$REPO_ROOT" "$hash_name" "$manifest") || result="ORPHANED"
    else
      # Full-workspace fallback: hash must be in the valid-hash set
      if grep -qxF "$hash_name" "$VALID_HASHES_FILE" 2>/dev/null; then
        result="VALID"
      else
        result="ORPHANED"
      fi
    fi

    [ "$result" = "ORPHANED" ] && printf '%s\n' "$hash_dir" >> "$ORPHANS_FILE"

  done < <(find "$shard_dir" -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)

done < <(find "$HASH_RECORD_DIR" -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)

# ---------------------------------------------------------------------------
# Count orphans
# ---------------------------------------------------------------------------
orphan_count=0
if [ -s "$ORPHANS_FILE" ]; then
  orphan_count=$(grep -c '' "$ORPHANS_FILE") || orphan_count=0
fi

# ---------------------------------------------------------------------------
# Dry-run
# ---------------------------------------------------------------------------
if [ "$DRY_RUN" = "1" ]; then
  echo "dry-run: $orphan_count"
  exit 0
fi

# CLEAN if no orphans
if [ "$orphan_count" -eq 0 ]; then
  echo "CLEAN"
  exit 0
fi

# ---------------------------------------------------------------------------
# Delete orphans (up to --limit)
# ---------------------------------------------------------------------------
deleted=0
while IFS= read -r odir || [ -n "$odir" ]; do
  [ -z "$odir" ] && continue

  # Cap at limit (LIMIT=-1 means unlimited)
  if [ "$LIMIT" -ge 0 ] 2>/dev/null && [ "$deleted" -ge "$LIMIT" ]; then
    break
  fi

  # Safety: path must be under .hash-record/
  case "$odir" in
    "${HASH_RECORD_DIR}"/*)
      rm -rf "$odir"
      deleted=$((deleted + 1))
      ;;
    *)
      echo "skipping path outside .hash-record/: $odir" >&2
      ;;
  esac

done < "$ORPHANS_FILE"

# ---------------------------------------------------------------------------
# Prune empty directories — bottom-up (-depth) so parents are cleaned after
# children. Skips dot-prefixed admin dirs directly under .hash-record/.
# ---------------------------------------------------------------------------
while IFS= read -r -d '' empty_dir; do
  # Never remove admin dirs (dot-prefixed directly under .hash-record/)
  parent_dir=$(dirname "$empty_dir")
  dir_name=$(basename "$empty_dir")
  if [ "$parent_dir" = "$HASH_RECORD_DIR" ]; then
    case "$dir_name" in .*) continue ;; esac
  fi
  rmdir "$empty_dir" 2>/dev/null || true
done < <(find "$HASH_RECORD_DIR" -mindepth 1 -depth -type d -empty -print0 2>/dev/null)

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------
if [ "$deleted" -eq 0 ]; then
  echo "CLEAN"
else
  echo "pruned: $deleted"
fi

exit 0
