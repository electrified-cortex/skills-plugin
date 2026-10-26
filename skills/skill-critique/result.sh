#!/usr/bin/env bash
# result.sh — skill-critique result tool
# Usage: result.sh <skill_dir> <tier>
# Outputs one of:
#   PASS: <abs-path>    (HIT, cached critique report exists) (exit 0)
#   MISS: <abs-path>    (no cache; this is the report path)  (exit 0)
#   ERROR: <reason>     (argument or runtime error)          (exit 1)
set -e

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  cat <<'USAGE'
Usage: result.sh <skill_dir> <tier>

Wraps hash-record/manifest for skill-critique and checks whether a critique at
<tier> has already been run on the exact current content of the skill. Each tier
has its own cache entry.

Arguments:
  skill_dir        Absolute path to the skill folder being critiqued.
  tier             fast-cheap | standard | deep | fast-cheap-x3 (whole value,
                   case-sensitive).

Options:
  --help / -h      Print usage, exit 0.

Output (stdout, one line):
  PASS: <abs-path>    Cached critique report exists at <abs-path>.
  MISS: <abs-path>    No cache entry; executor MUST write here.
  ERROR: <reason>     Argument, runtime, or missing-dependency error.

Exit codes:
  0  Success (PASS or MISS).
  1  Error.
USAGE
  exit 0
fi

POSITIONAL=("$@")

if [ "${#POSITIONAL[@]}" -lt 2 ] || [ -z "${POSITIONAL[0]}" ] || [ -z "${POSITIONAL[1]}" ]; then
  echo "ERROR: missing argument -- expected <skill_dir> <tier>"
  exit 1
fi

SKILL_DIR="${POSITIONAL[0]}"
TIER="${POSITIONAL[1]}"
RECORD_FILE="report.md"

# Whitelist: the whole value must equal one of the names below (case-sensitive).
case "$TIER" in
  fast-cheap|standard|deep|fast-cheap-x3) ;;
  *)
    echo "ERROR: invalid tier -- expected fast-cheap, standard, deep or fast-cheap-x3"
    exit 1
    ;;
esac

if [ ! -d "$SKILL_DIR" ]; then
  echo "ERROR: skill_dir not found: $SKILL_DIR"
  exit 1
fi

SKILL_DIR=$(cd "$SKILL_DIR" && pwd)

# Enumerate only the semantic content files the critique agent reads.
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

# op_kind carries the tier: one cache entry per (skill hash, tier)
OP_KIND="skill-critique/v2/${TIER}"

# Locate sibling manifest tool
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
MANIFEST_SH="${SCRIPT_DIR}/../hash-record/manifest/manifest.sh"

if [ ! -f "$MANIFEST_SH" ]; then
  echo "ERROR: cannot locate hash-record/manifest at: $MANIFEST_SH"
  exit 1
fi

# Normalize a path string to forward slashes
normalize_path() {
  echo "${1//\\//}"
}

# Invoke manifest
# "|| true": a failing manifest prints its ERROR line; relay it below, do not exit here under set -e
MANIFEST_OUT=$(bash "$MANIFEST_SH" "$OP_KIND" "$RECORD_FILE" "${FILES[@]}") || true
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
    echo "PASS: $REPORT_PATH"
    exit 0
    ;;
  *)
    echo "ERROR: unrecognized hash-record/manifest output: $MANIFEST_OUT"
    exit 1
    ;;
esac
