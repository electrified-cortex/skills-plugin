#!/usr/bin/env bash
# result.sh — skill-auditing result tool
# Usage: result.sh <skill_dir>
# Outputs one of:
#   CLEAN: <abs-path>           (HIT, result: clean)        (exit 0)
#   PASS: <abs-path>            (HIT, result: pass)         (exit 0)
#   NEEDS_REVISION: <abs-path>  (HIT, result: findings)     (exit 0)
#   FAIL: <abs-path>            (HIT, result: fail)         (exit 0)
#   MISS: <abs-path>            (no cache; this is the report path) (exit 0)
#   ERROR: <reason>             (argument or runtime error) (exit 1)
set -e

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  cat <<'USAGE'
Usage: result.sh <skill_dir>

Wraps hash-record-manifest for skill-auditing and translates a HIT into
the cached audit verdict by reading the report's frontmatter.

Arguments:
  skill_dir        Absolute path to the skill folder being audited.

Options:
  --help / -h      Print usage, exit 0.

Output (stdout, one line):
  CLEAN: <abs-path>           Cached report says result: clean.
  PASS: <abs-path>            Cached report says result: pass.
  NEEDS_REVISION: <abs-path>  Cached report says result: findings.
  FAIL: <abs-path>            Cached report says result: fail.
  MISS: <abs-path>            No cache entry; executor MUST write here.
  ERROR: <reason>             Argument, runtime, or malformed-record error.

Exit codes:
  0  Success (PASS, NEEDS_REVISION, FAIL, or MISS).
  1  Error.
USAGE
  exit 0
fi

POSITIONAL=("$@")

if [ "${#POSITIONAL[@]}" -lt 1 ]; then
  echo "ERROR: missing argument -- expected <skill_dir>"
  exit 1
fi

SKILL_DIR="${POSITIONAL[0]}"
RECORD_FILE="report.md"

if [ ! -d "$SKILL_DIR" ]; then
  echo "ERROR: skill_dir not found: $SKILL_DIR"
  exit 1
fi

SKILL_DIR=$(cd "$SKILL_DIR" && pwd)

# Enumerate only the semantic content files the audit agent reads.
# Hashing all files causes indeterminism when non-semantic files are
# added/modified between the pre- and post-dispatch result calls.
# Order is intentional — hash key must be identical between pre- and post-dispatch calls.
# Do not sort or reorder this list.
SEMANTIC_NAMES=("SKILL.md" "instructions.txt" "spec.md" "uncompressed.md" "instructions.uncompressed.md")
FILES=()
for NAME in "${SEMANTIC_NAMES[@]}"; do
    CANDIDATE="$SKILL_DIR/$NAME"
    if [ -f "$CANDIDATE" ]; then
        FILES+=("$CANDIDATE")
    fi
done

if [ "${#FILES[@]}" -eq 0 ]; then
  echo "ERROR: no semantic content files found in skill_dir"
  exit 1
fi

# Single canonical op_kind
OP_KIND="skill-auditing/v2"

# Locate sibling manifest tool
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
MANIFEST_SH="${SCRIPT_DIR}/../hash-record/hash-record-manifest/manifest.sh"

if [ ! -f "$MANIFEST_SH" ]; then
  echo "ERROR: cannot locate hash-record-manifest at: $MANIFEST_SH"
  exit 1
fi

# Normalize a path string to forward slashes
normalize_path() {
  echo "${1//\\//}"
}

# Invoke manifest
MANIFEST_OUT=$(bash "$MANIFEST_SH" "$OP_KIND" "$RECORD_FILE" "${FILES[@]}")
MANIFEST_OUT=$(normalize_path "$MANIFEST_OUT")

case "$MANIFEST_OUT" in
  "MISS: "*)
    echo "$MANIFEST_OUT"
    exit 0
    ;;
  "ERROR: "*)
    echo "$MANIFEST_OUT"
    exit 1
    ;;
  "HIT: "*)
    REPORT_PATH=$(normalize_path "${MANIFEST_OUT#HIT: }")
    if [ ! -f "$REPORT_PATH" ]; then
      echo "ERROR: cache record vanished at: $REPORT_PATH"
      exit 1
    fi
    RESULT_VALUE=$(grep -m1 '^result:' "$REPORT_PATH" 2>/dev/null | awk '{print $2}')
    case "$RESULT_VALUE" in
      clean)
        echo "CLEAN: $REPORT_PATH"
        exit 0
        ;;
      pass)
        echo "PASS: $REPORT_PATH"
        exit 0
        ;;
      findings)
        echo "NEEDS_REVISION: $REPORT_PATH"
        exit 0
        ;;
      fail)
        echo "FAIL: $REPORT_PATH"
        exit 0
        ;;
      *)
        echo "ERROR: malformed cache record at $REPORT_PATH"
        exit 1
        ;;
    esac
    ;;
  *)
    echo "ERROR: unrecognized hash-record-manifest output: $MANIFEST_OUT"
    exit 1
    ;;
esac
