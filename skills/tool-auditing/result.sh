#!/usr/bin/env bash
# result.sh — tool-auditing result tool
# Wraps hash-record-manifest and translates HIT into the cached audit verdict.
# Resolves the tool trio (<stem>.sh, <stem>.ps1, <stem>.spec.md) from tool_path.
# Usage: result <tool_path>
# Outputs one of:
#   PASS: <abs-path>                  (HIT, result: pass)               (exit 0)
#   PASS_WITH_FINDINGS: <abs-path>    (HIT, result: pass-with-findings) (exit 0)
#   FAIL: <abs-path>                  (HIT, result: fail)               (exit 0)
#   MISS: <abs-path>                  (no cache; this is the report path) (exit 0)
#   ERROR: <reason>                                                     (exit 1)
set -e

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  cat <<'USAGE'
Usage: result <tool_path>

Wraps hash-record-manifest for tool-auditing and translates a HIT into
the cached audit verdict. Resolves the tool trio from any input member.

Arguments:
  tool_path  Absolute path to ANY member of the tool trio:
             <stem>.sh, <stem>.ps1, or <stem>.spec.md.
             Missing trio members are reported as audit FAIL by the executor
             (Check 1). result builds the manifest from whichever exist.

Output (stdout, one line):
  PASS: <abs-path>                Cached report says result: pass.
  PASS_WITH_FINDINGS: <abs-path>  Cached report says result: pass-with-findings.
  FAIL: <abs-path>                Cached report says result: fail.
  MISS: <abs-path>                No cache entry; executor MUST write here.
  ERROR: <reason>                 Argument, runtime, or malformed-record error.

Exit codes:
  0  Success (PASS, PASS_WITH_FINDINGS, FAIL, or MISS).
  1  Error.
USAGE
  exit 0
fi

if [ "$#" -lt 1 ]; then
  echo "ERROR: missing argument -- expected <tool_path>"
  exit 1
fi

TOOL_PATH="$1"

if [ ! -f "$TOOL_PATH" ]; then
  echo "ERROR: tool_path not found: $TOOL_PATH"
  exit 1
fi

# Resolve dir + filename
TOOL_DIR="$( cd "$( dirname "$TOOL_PATH" )" && pwd )"
BASENAME="$(basename "$TOOL_PATH")"

# Derive stem from filename
case "$BASENAME" in
  *.spec.md)
    STEM="${BASENAME%.spec.md}"
    ;;
  *.sh)
    STEM="${BASENAME%.sh}"
    ;;
  *.ps1)
    STEM="${BASENAME%.ps1}"
    ;;
  *)
    echo "ERROR: unsupported tool extension: $BASENAME"
    exit 1
    ;;
esac

# Resolve trio members
SH_PATH="$TOOL_DIR/$STEM.sh"
PS1_PATH="$TOOL_DIR/$STEM.ps1"
SPEC_PATH="$TOOL_DIR/$STEM.spec.md"

FILES=()
[ -f "$SH_PATH" ] && FILES+=("$SH_PATH")
[ -f "$PS1_PATH" ] && FILES+=("$PS1_PATH")
[ -f "$SPEC_PATH" ] && FILES+=("$SPEC_PATH")

# Locate sibling manifest tool
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
MANIFEST_SH="${SCRIPT_DIR}/../hash-record/hash-record-manifest/manifest.sh"

if [ ! -f "$MANIFEST_SH" ]; then
  echo "ERROR: cannot locate hash-record-manifest at: $MANIFEST_SH"
  exit 1
fi

# Invoke manifest (op_kind v2 — trio scope)
MANIFEST_OUT=$(bash "$MANIFEST_SH" "tool-auditing/v2" "report.md" "${FILES[@]}" 2>/dev/null) || {
  echo "ERROR: hash-record-manifest failed for: $TOOL_PATH"
  exit 1
}

# Branch on manifest stdout
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
    REPORT_PATH="${MANIFEST_OUT#HIT: }"
    if [ ! -f "$REPORT_PATH" ]; then
      echo "ERROR: cache record vanished at: $REPORT_PATH"
      exit 1
    fi
    RESULT_VALUE=$(grep -m1 '^result:' "$REPORT_PATH" 2>/dev/null | awk '{print $2}')
    case "$RESULT_VALUE" in
      pass)
        echo "PASS: $REPORT_PATH"
        exit 0
        ;;
      pass-with-findings)
        echo "PASS_WITH_FINDINGS: $REPORT_PATH"
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
