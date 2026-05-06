#!/usr/bin/env bash
# verify.sh — deterministic markdown hygiene check
# Covered rules: MD010, MD041, MONO-ESCAPE
# Usage: verify.sh <file> [--ignore RULE[,RULE...]]
# Output: CLEAN | violation pairs (rule line + Fix line per violation), LF-terminated
# Exit: 0 on success; 1 on usage/file error (errors to stderr)
# Dependencies: bash 4.3+, tail. No installs required.

set -euo pipefail

if [[ $# -lt 1 ]]; then
  printf 'ERROR: usage: verify.sh <file> [--ignore RULE[,RULE...]]\n' >&2
  exit 1
fi

FILE="$1"
if [[ ! -f "$FILE" ]]; then
  printf 'ERROR: file not found: %s\n' "$FILE" >&2
  exit 1
fi

declare -A SKIP=()
shift
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ignore)
      shift
      if [[ $# -gt 0 ]]; then
        IFS=',' read -ra _RULES <<< "$1"
        for r in "${_RULES[@]}"; do SKIP["${r// /}"]=1; done
        shift
      fi
      ;;
    *) shift ;;
  esac
done

has_skip() { [[ "${SKIP[$1]+x}" ]]; }

mapfile -t LINES < "$FILE"
N="${#LINES[@]}"

declare -a OUT=()

add() { OUT+=("$1" "$2"); }

# Detect YAML frontmatter for MD041 suppression
HAS_FM=false
for (( i=0; i<N; i++ )); do
  [[ "${LINES[$i]}" =~ ^[[:space:]]*$ ]] && continue
  [[ "${LINES[$i]}" == "---" ]] && HAS_FM=true
  break
done

in_fence=false

for (( i=0; i<N; i++ )); do
  L="${LINES[$i]}"
  LN=$((i + 1))

  is_fence=false
  if [[ "$L" =~ ^\`\`\` ]]; then
    is_fence=true
    [[ "$in_fence" == true ]] && in_fence=false || in_fence=true
  fi

  # MD010 — hard tabs outside fenced code blocks (skip fence delimiter lines)
  if ! has_skip MD010 \
      && [[ "$in_fence" == false ]] \
      && [[ "$is_fence" == false ]] \
      && [[ "$L" == *$'\t'* ]]; then
    add "MD010 line $LN: hard tab in non-code content" \
        "Fix: replace tab character on line $LN with spaces"
  fi

  # MONO-ESCAPE — backslash-backtick inside inline code (outside fenced blocks)
  if ! has_skip MONO-ESCAPE \
      && [[ "$in_fence" == false ]] \
      && [[ "$is_fence" == false ]]; then
    case "$L" in
      *'\`'*)
        add "MONO-ESCAPE line $LN: [HIGH] backslash-backtick escape in inline code - breaks Markdown rendering" \
            "Fix: use double-backtick fence: \`\` text with \`backtick\` \`\` instead of single-backtick + backslash-escape"
        ;;
    esac
  fi

done

# MD041 — first non-blank line must be H1 (suppressed when frontmatter detected)
if ! has_skip MD041 && [[ "$HAS_FM" == false ]]; then
  for (( i=0; i<N; i++ )); do
    [[ "${LINES[$i]}" =~ ^[[:space:]]*$ ]] && continue
    if ! [[ "${LINES[$i]}" =~ ^#[[:space:]] ]]; then
      add "MD041 line $((i+1)): first non-blank line is not an H1 heading" \
          "Fix: add a top-level heading (# Title) as the first non-blank line of the file"
    fi
    break
  done
fi

if (( ${#OUT[@]} == 0 )); then
  printf 'CLEAN\n'
else
  printf '%s\n' "${OUT[@]}"
fi
