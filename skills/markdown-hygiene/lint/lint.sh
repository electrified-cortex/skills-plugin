#!/usr/bin/env bash
# lint.sh — in-place auto-fix: MD009 (trailing spaces), MD012 (consecutive blank lines), MD047 (trailing newline)
# Usage: lint.sh <path-or-glob> [<path-or-glob> ...]
# Exit: 0 all matched files processed; 1 usage error or plain path not found/writable
# Deps: bash 4.3+. No external tools.

set -euo pipefail

if [[ $# -eq 0 ]]; then
  printf 'ERROR: usage: lint.sh <path-or-glob> [<path-or-glob> ...]\n' >&2
  exit 1
fi

lint_file() {
  local FILE="$1"
  if [[ ! -f "$FILE" ]]; then
    printf 'ERROR: file not found: %s\n' "$FILE" >&2
    return 1
  fi
  if [[ ! -w "$FILE" ]]; then
    printf 'ERROR: file not writable: %s\n' "$FILE" >&2
    return 1
  fi

  mapfile -t LINES < "$FILE"

  local result=()
  local prev_blank=false

  for L in "${LINES[@]}"; do
    # Normalize CRLF
    L="${L%$'\r'}"
    # MD009: strip trailing whitespace
    while [[ "$L" =~ [[:space:]]$ ]]; do
      L="${L%?}"
    done
    # MD012: collapse consecutive blank lines
    if [[ "$L" =~ ^[[:space:]]*$ ]]; then
      [[ "$prev_blank" == true ]] && continue
      prev_blank=true
    else
      prev_blank=false
    fi
    result+=("$L")
  done

  # Write UTF-8 LF; MD047: printf '%s\n' appends LF after every line including last
  if (( ${#result[@]} > 0 )); then
    printf '%s\n' "${result[@]}" > "$FILE"
  else
    printf '' > "$FILE"
  fi
}

exit_code=0
for pattern in "$@"; do
  # Check if pattern is a glob (contains * or ?)
  if [[ "$pattern" == *'*'* || "$pattern" == *'?'* ]]; then
    # Expand glob; if no match, nullglob silently skips
    shopt -s nullglob
    for f in $pattern; do
      lint_file "$f" || exit_code=1
    done
    shopt -u nullglob
  else
    lint_file "$pattern" || exit_code=1
  fi
done
exit $exit_code
