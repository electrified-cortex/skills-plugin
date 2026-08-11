#!/usr/bin/env bash
# scrub.sh -- mojibake / non-ASCII scrubber (detect + fix)
# Usage: scrub.sh <file_path|-> [--fix] [--stdout-only] [--ignore <CATEGORY>]... [--help]
# See scrub.spec.md for the full contract. Keep in sync with scrub.ps1 --
# both must produce byte-identical stdout for the same inputs.
# set -e is safe here even though this script relies on grep returning
# non-zero for "no match": every grep/is_valid_category/is_ignored call
# that can legitimately fail is used as the condition of an if/while, or
# negated with !, both of which set -e exempts (see bash(1) "set -e").
set -eu

# -----------------------------------------------------------------------
# Help (checked first, anywhere in argv -- always wins)
# -----------------------------------------------------------------------
usage() {
  cat <<'USAGE'
Usage: scrub <file_path> [--fix] [--stdout-only] [--ignore <CATEGORY>]... [--help]

Detect and fix mojibake and non-ASCII punctuation (arrows, dashes, quotes,
ellipsis, bullets) in a text file. Detect-only by default.

Arguments:
  file_path             Absolute path to the file to scan, or - for stdin.

Flags:
  --fix                 Apply replacements in place. Default is detect-only.
  --stdout-only         Emit the fixed content to stdout without modifying
                         the source file. Mutually exclusive with --fix.
  --ignore <CATEGORY>   Skip a category. Repeatable; value may be a
                         comma-separated list. CATEGORY is one of:
                         mojibake, arrows, dashes, quotes, ellipsis, bullets.
  --help, -h            Print this usage and exit 0.

Output (stdout):
  CLEAN                    Detect mode: nothing to scrub.
  FINDINGS: <count>        Detect mode: followed by one line per finding:
                              <line>: <category>: '<original>' -> '<replacement>'
  FIXED: <count> replacements applied to <file_path>
                            --fix mode result.
  <transformed content>    --stdout-only mode: raw fixed content, no wrapper.
  ERROR: <reason>          Argument or runtime error.

Exit codes:
  0   Success (CLEAN, FINDINGS, FIXED, --stdout-only output, or --help).
  1   Error.
USAGE
}

for _a in "$@"; do
  if [ "$_a" = "--help" ] || [ "$_a" = "-h" ]; then
    usage
    exit 0
  fi
done

# -----------------------------------------------------------------------
# Argument parsing
# -----------------------------------------------------------------------
FILE_PATH=""
FIX=0
STDOUT_ONLY=0
IGNORE_CATS=""

VALID_CATEGORIES="mojibake arrows dashes quotes ellipsis bullets"

is_valid_category() {
  local c="$1" v
  for v in $VALID_CATEGORIES; do
    [ "$c" = "$v" ] && return 0
  done
  return 1
}

is_ignored() {
  local c="$1" ig
  for ig in $IGNORE_CATS; do
    [ "$c" = "$ig" ] && return 0
  done
  return 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --fix)
      FIX=1
      shift
      ;;
    --stdout-only)
      STDOUT_ONLY=1
      shift
      ;;
    --ignore)
      if [ $# -lt 2 ]; then
        echo "ERROR: missing value for --ignore"
        exit 1
      fi
      IFS=',' read -ra _cats <<< "$2"
      for _c in "${_cats[@]}"; do
        if ! is_valid_category "$_c"; then
          echo "ERROR: invalid category: $_c"
          exit 1
        fi
        IGNORE_CATS="$IGNORE_CATS $_c"
      done
      shift 2
      ;;
    --*)
      echo "ERROR: unknown argument: $1"
      exit 1
      ;;
    *)
      if [ -n "$FILE_PATH" ]; then
        echo "ERROR: unexpected argument: $1"
        exit 1
      fi
      FILE_PATH="$1"
      shift
      ;;
  esac
done

if [ -z "$FILE_PATH" ]; then
  echo "ERROR: missing required argument: file_path"
  exit 1
fi

if [ "$FIX" -eq 1 ] && [ "$STDOUT_ONLY" -eq 1 ]; then
  echo "ERROR: --fix and --stdout-only are mutually exclusive"
  exit 1
fi

if [ "$FILE_PATH" = "-" ] && [ "$FIX" -eq 1 ]; then
  echo "ERROR: --fix cannot be used with stdin input (use --stdout-only instead)"
  exit 1
fi

if [ "$FILE_PATH" != "-" ]; then
  case "$FILE_PATH" in
    /*) ;;
    [A-Za-z]:*) ;;
    *)
      echo "ERROR: file_path must be an absolute path (or '-' for stdin): $FILE_PATH"
      exit 1
      ;;
  esac
  if [ ! -e "$FILE_PATH" ]; then
    echo "ERROR: file not found: $FILE_PATH"
    exit 1
  fi
  if [ ! -f "$FILE_PATH" ]; then
    echo "ERROR: not a regular file: $FILE_PATH"
    exit 1
  fi
  if [ ! -r "$FILE_PATH" ]; then
    echo "ERROR: cannot read file: $FILE_PATH"
    exit 1
  fi
fi

# -----------------------------------------------------------------------
# Working copy
# -----------------------------------------------------------------------
WORKFILE=$(mktemp) || { echo "ERROR: failed to create temp file"; exit 1; }
MATCHES=$(mktemp) || { echo "ERROR: failed to create temp file"; exit 1; }
FINDINGS_RAW=$(mktemp) || { echo "ERROR: failed to create temp file"; exit 1; }
trap 'rm -f "$WORKFILE" "$WORKFILE.new" "$MATCHES" "$FINDINGS_RAW"' EXIT

if [ "$FILE_PATH" = "-" ]; then
  cat > "$WORKFILE"
else
  cp "$FILE_PATH" "$WORKFILE" || { echo "ERROR: cannot read file: $FILE_PATH"; exit 1; }
fi

# -----------------------------------------------------------------------
# Canonical replacement table -- keep in exact sync with scrub.ps1.
# Order matters: mojibake sequences are matched/replaced before the
# categories below so a mojibake sequence is never double-counted as a
# plain quote/dash/etc once its trailing byte happens to render as one.
# See scrub.spec.md for the full table with codepoints and rationale.
# -----------------------------------------------------------------------
PATTERN=(
  'â€™'
  'â€˜'
  'â€œ'
  'â€“'
  'â€”'
  'â€¢'
  'â€¦'
  'Â '
  '→'
  '←'
  '↑'
  '↓'
  '↔'
  '⇒'
  '⇐'
  '⇔'
  '—'
  '–'
  '‘'
  '’'
  '“'
  '”'
  '…'
  '•'
  '◦'
  '‣'
  '●'
  '▪'
  '▫'
)
REPLACE=(
  ''"'"''
  ''"'"''
  '"'
  '-'
  '--'
  '-'
  '...'
  ''
  '->'
  '<-'
  '^'
  'v'
  '<->'
  '=>'
  '<='
  '<=>'
  '--'
  '-'
  ''"'"''
  ''"'"''
  '"'
  '"'
  '...'
  '-'
  '-'
  '-'
  '-'
  '-'
  '-'
)
CATEGORY=(
  'mojibake'
  'mojibake'
  'mojibake'
  'mojibake'
  'mojibake'
  'mojibake'
  'mojibake'
  'mojibake'
  'arrows'
  'arrows'
  'arrows'
  'arrows'
  'arrows'
  'arrows'
  'arrows'
  'arrows'
  'dashes'
  'dashes'
  'quotes'
  'quotes'
  'quotes'
  'quotes'
  'ellipsis'
  'bullets'
  'bullets'
  'bullets'
  'bullets'
  'bullets'
  'bullets'
)
AUTOFIX=(
  1
  1
  1
  1
  1
  1
  1
  0
  1
  1
  1
  1
  1
  1
  1
  1
  1
  1
  1
  1
  1
  1
  1
  1
  1
  1
  1
  1
  1
)
MANUAL_MARKER="(manual review -- no safe auto-fix)"

# -----------------------------------------------------------------------
# Scan + replace, one pattern at a time, in table order.
# -----------------------------------------------------------------------
TOTAL_FIX_COUNT=0
: > "$FINDINGS_RAW"

_idx=0
_n=${#PATTERN[@]}
while [ "$_idx" -lt "$_n" ]; do
  pat="${PATTERN[$_idx]}"
  rep="${REPLACE[$_idx]}"
  cat_name="${CATEGORY[$_idx]}"
  af="${AUTOFIX[$_idx]}"

  if is_ignored "$cat_name"; then
    _idx=$((_idx + 1))
    continue
  fi

  : > "$MATCHES"
  if grep -n -F -o -- "$pat" "$WORKFILE" > "$MATCHES" 2>/dev/null; then
    match_count=$(wc -l < "$MATCHES" | tr -d ' ')

    if [ "$af" -eq 1 ]; then
      disp_rep="$rep"
    else
      disp_rep="$MANUAL_MARKER"
    fi

    while IFS=: read -r lnum _rest; do
      printf "%08d\t%03d\t%s: %s: '%s' -> '%s'\n" \
        "$lnum" "$_idx" "$lnum" "$cat_name" "$pat" "$disp_rep" >> "$FINDINGS_RAW"
    done < "$MATCHES"

    if [ "$af" -eq 1 ]; then
      TOTAL_FIX_COUNT=$((TOTAL_FIX_COUNT + match_count))
      sed "s/${pat}/${rep}/g" "$WORKFILE" > "$WORKFILE.new" && mv "$WORKFILE.new" "$WORKFILE"
    fi
  fi

  _idx=$((_idx + 1))
done

TOTAL_FINDING_COUNT=$(wc -l < "$FINDINGS_RAW" | tr -d ' ')

# -----------------------------------------------------------------------
# Output
# -----------------------------------------------------------------------
if [ "$STDOUT_ONLY" -eq 1 ]; then
  cat "$WORKFILE"
  exit 0
fi

if [ "$FIX" -eq 1 ]; then
  if [ "$TOTAL_FIX_COUNT" -gt 0 ]; then
    cp "$WORKFILE" "$FILE_PATH" || { echo "ERROR: failed to write file: $FILE_PATH"; exit 1; }
  fi
  echo "FIXED: $TOTAL_FIX_COUNT replacements applied to $FILE_PATH"
  exit 0
fi

if [ "$TOTAL_FINDING_COUNT" -eq 0 ]; then
  echo "CLEAN"
  exit 0
fi

echo "FINDINGS: $TOTAL_FINDING_COUNT"
sort -t "$(printf '\t')" -k1,1 -k2,2 -s "$FINDINGS_RAW" | cut -f3-
exit 0
