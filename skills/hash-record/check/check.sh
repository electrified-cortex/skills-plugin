#!/usr/bin/env bash
# check.sh — hash-record cache probe
# Usage: check <file_path> <op_kind> <record_filename>
# Outputs one of: HIT: <abs-path>   (file exists; caller reads)  (exit 0)
#                 MISS: <abs-path>  (file absent; caller writes)  (exit 0)
#                 ERROR: <reason>                                 (exit 1)
set -e

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  cat <<'USAGE'
Usage: check <file_path> <op_kind> <record_filename>

Probe the hash-record cache for <file_path>.

Arguments:
  file_path        Absolute path to the file to probe (must be readable).
  op_kind          Operation kind, e.g. "markdown-hygiene" or "skill-auditing/v2". May contain /.
  record_filename  Leaf filename, e.g. "report.md". No path separators.

Output (stdout, one line):
  HIT: <abs-path>         Cache file exists; caller reads its contents.
  MISS: <abs-path>        No cache entry; this is the path to write to.
  ERROR: <reason>         Argument or runtime error.

Exit codes:
  0   Success (HIT or MISS).
  1   Error.
USAGE
  exit 0
fi

# ---------------------------------------------------------------------------
# Argument validation
# ---------------------------------------------------------------------------
if [ "$#" -lt 3 ]; then
  echo "ERROR: missing arguments -- expected <file_path> <op_kind> <record_filename>"
  exit 1
fi

FILE_PATH="$1"
OP_KIND="$2"
RECORD_FILENAME="$3"

# Reject path traversal in op_kind and record_filename
case "$OP_KIND" in
  *..* | *\*)
    echo "ERROR: invalid op_kind: $OP_KIND"
    exit 1
    ;;
esac

case "$RECORD_FILENAME" in
  *..* | */* | *\*)
    echo "ERROR: invalid record_filename: $RECORD_FILENAME"
    exit 1
    ;;
esac

# ---------------------------------------------------------------------------
# Helper: compute LF-normalized blob hash (CRLF/CR -> LF before hashing).
# Produces identical hash regardless of platform git config or CWD location.
# ---------------------------------------------------------------------------
lf_blob_hash() {
  local file="$1"
  tr -d '\r' < "$file" | git hash-object --stdin 2>/dev/null
}

# ---------------------------------------------------------------------------
# Resolve repo root
# ---------------------------------------------------------------------------
TARGET_DIR=$(dirname "$FILE_PATH")
REPO_ROOT=$(git -C "$TARGET_DIR" rev-parse --show-toplevel 2>/dev/null) || true
if [ -z "$REPO_ROOT" ]; then
  REPO_ROOT="$TARGET_DIR"
  echo "WARN: not in a git repo; falling back to file's parent dir as repo_root: $REPO_ROOT" >&2
fi

# ---------------------------------------------------------------------------
# Compute git blob hash (LF-normalized for cross-platform determinism)
# ---------------------------------------------------------------------------
HASH=$(lf_blob_hash "$FILE_PATH")
if [ -z "$HASH" ]; then
  echo "ERROR: git hash-object failed for: $FILE_PATH"
  exit 1
fi

# ---------------------------------------------------------------------------
# Construct paths
# ---------------------------------------------------------------------------
SHARD="${HASH:0:2}"
CACHE_DIR="${REPO_ROOT}/.hash-record/${SHARD}/${HASH}/${OP_KIND}"
CACHE_PATH="${CACHE_DIR}/${RECORD_FILENAME}"

# ---------------------------------------------------------------------------
# Probe cache — same path returned on HIT and MISS.
#   HIT  -> caller reads it.
#   MISS -> caller writes to it.
# ---------------------------------------------------------------------------
if [ -f "$CACHE_PATH" ]; then
  echo "HIT: $CACHE_PATH"
  exit 0
fi

echo "MISS: $CACHE_PATH"
exit 0
