#!/usr/bin/env bash
# manifest.sh — hash-record multi-file manifest probe
# Usage: manifest <op_kind> <record_filename> <file1> [<file2> ...]
# Outputs one of: HIT: <path>   (exit 0)
#                 MISS: <path>  (exit 0)
#                 ERROR: <reason> (exit 1)
set -e

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  cat <<'USAGE'
Usage: manifest <op_kind> <record_filename> <file1> [<file2> ...]

Probe the hash-record cache for a set of files via a combined manifest hash.

Arguments:
  op_kind          Operation kind, e.g. "markdown-hygiene" or "skill-auditing/v2".
                   May contain /. Must NOT contain .., \, or *.
  record_filename  Leaf filename, e.g. "report.md". No path separators.
  file1 ...        One or more file paths (relative or absolute, must be readable).

Output (stdout, one line):
  HIT: <abs-path>   Cache file exists; caller reads its contents.
  MISS: <abs-path>  No cache entry; this is the path to write to.
  ERROR: <reason>   Argument or runtime error.

Exit codes:
  0   Success (HIT or MISS).
  1   Error.
USAGE
  exit 0
fi

if [ "$#" -lt 3 ]; then
  echo "ERROR: missing arguments -- expected <op_kind> <record_filename> <file1> [<file2> ...]"
  exit 1
fi

OP_KIND="$1"
RECORD_FILENAME="$2"
shift 2
# Remaining args are files
FILES=("$@")

# Validate op_kind: reject .., \, *  (/ is allowed for versioning)
case "$OP_KIND" in
  *..* | *\\* | *\*)
    echo "ERROR: invalid op_kind: $OP_KIND"
    exit 1
    ;;
esac

# Validate record_filename: reject .., \, /, *
case "$RECORD_FILENAME" in
  *..* | */* | *\\* | *\*)
    echo "ERROR: invalid record_filename: $RECORD_FILENAME"
    exit 1
    ;;
esac

# Step 1: Resolve repo root from the FIRST file
FIRST_FILE="${FILES[0]}"
TARGET_DIR=$(dirname "$FIRST_FILE")
REPO_ROOT=$(git -C "$TARGET_DIR" rev-parse --show-toplevel 2>/dev/null) || true
if [ -z "$REPO_ROOT" ]; then
  REPO_ROOT="$TARGET_DIR"
  echo "WARN: not in a git repo; falling back to file's parent dir as repo_root: $REPO_ROOT" >&2
fi

# Normalize repo_root to forward slashes (for cross-platform path stripping).
# Use tr — bash parameter expansion `${var//\\//}` is fragile across MSYS/Linux.
REPO_ROOT_FWD=$(printf '%s' "$REPO_ROOT" | tr '\\' '/')

# Step 2: For each file, resolve repo-relative path and compute blob hash
declare -a PAIRS=()

for FILE_PATH in "${FILES[@]}"; do
  # Resolve absolute path
  ABS_PATH=$(realpath "$FILE_PATH" 2>/dev/null) || {
    echo "ERROR: cannot resolve path: $FILE_PATH"
    exit 1
  }

  # Normalize to forward slashes (tr is reliable; parameter expansion is not).
  ABS_FWD=$(printf '%s' "$ABS_PATH" | tr '\\' '/')

  # MSYS / Git-Bash on Windows returns paths like /<drive>/<rest> — convert
  # to <DRIVE>:/<rest> so it matches `git rev-parse --show-toplevel` output
  # (which uses Windows-style drive letters with forward slashes).
  if [[ "$ABS_FWD" =~ ^/([a-zA-Z])/(.*)$ ]]; then
    DRIVE="${BASH_REMATCH[1]}"
    REST="${BASH_REMATCH[2]}"
    ABS_FWD="${DRIVE^^}:/${REST}"
  fi

  # Compute repo-relative path
  if [[ "$ABS_FWD" == "$REPO_ROOT_FWD"/* ]]; then
    REL_PATH="${ABS_FWD#"$REPO_ROOT_FWD/"}"
  else
    REL_PATH="$ABS_FWD"
  fi
  # Strip leading slash just in case (residual backslashes already converted via tr above).
  REL_PATH="${REL_PATH#/}"

  # Compute blob hash
  BLOB_HASH=$(tr -d '\r' < "$ABS_PATH" | git hash-object --stdin 2>/dev/null)
  if [ -z "$BLOB_HASH" ]; then
    echo "ERROR: git hash-object failed for: $REL_PATH"
    exit 1
  fi

  PAIRS+=("$REL_PATH $BLOB_HASH")
done

# Step 3: Sort pairs lexically by repo-relative path (byte-order ascending)
IFS=$'\n' SORTED_PAIRS=($(printf '%s\n' "${PAIRS[@]}" | LC_ALL=C sort))
unset IFS

# Step 4: Build manifest text — one line per pair, each ending with LF
MANIFEST_TEXT=""
for PAIR in "${SORTED_PAIRS[@]}"; do
  MANIFEST_TEXT="${MANIFEST_TEXT}${PAIR}"$'\n'
done

# Step 5: Compute manifest hash by piping manifest text through git hash-object --stdin
MANIFEST_HASH=$(printf '%s' "$MANIFEST_TEXT" | git hash-object --stdin)

if [ -z "$MANIFEST_HASH" ]; then
  echo "ERROR: git hash-object --stdin returned empty manifest hash"
  exit 1
fi

# Step 6: Construct cache path
SHARD="${MANIFEST_HASH:0:2}"
CACHE_PATH="${REPO_ROOT_FWD}/.hash-record/${SHARD}/${MANIFEST_HASH}/${OP_KIND}/${RECORD_FILENAME}"

# Step 7: Test whether cache file exists
if [ -f "$CACHE_PATH" ]; then
  echo "HIT: $CACHE_PATH"
  exit 0
fi

echo "MISS: $CACHE_PATH"
exit 0
