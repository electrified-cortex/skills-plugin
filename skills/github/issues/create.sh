#!/usr/bin/env bash
# create.sh — Create a GitHub issue via gh issue create.
# Stdout: issue URL (single line) on success. Nothing else on stdout.
# Stderr: error messages.
# Exit codes: 0=created, 2=usage error, 4=gh error.
set -euo pipefail

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
  cat <<'EOF'
Usage: bash create.sh [FLAGS]

Create a GitHub issue via gh issue create.

Required flags:
  --owner <name>       GitHub org or user
  --repo <name>        Repository name
  --title <text>       Issue title
  --body-file <path>   Path to a markdown body file (passed to gh by path)

Optional flags:
  --label <labels>     Comma-separated label names
  --help, -h           Print this usage and exit 0

Stdout: issue URL on success (single LF-terminated line). Nothing else.
Exit:   0=created  2=usage-error  4=gh-error
EOF
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
OWNER=''
REPO=''
TITLE=''
BODY_FILE=''
LABEL=''

# A value flag as the last argument must fail with exit 2, not abort under set -u.
need_value() { [[ $# -ge 2 ]] || { printf 'USAGE_ERROR: %s requires a value\n' "$1" >&2; exit 2; }; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --owner)      need_value "$@"; OWNER="$2";     shift 2 ;;
    --repo)       need_value "$@"; REPO="$2";      shift 2 ;;
    --title)      need_value "$@"; TITLE="$2";     shift 2 ;;
    --body-file)  need_value "$@"; BODY_FILE="$2"; shift 2 ;;
    --label)      need_value "$@"; LABEL="$2";     shift 2 ;;
    --help|-h)    usage; exit 0 ;;
    *)
      printf 'USAGE_ERROR: unknown flag: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------
missing=''
[[ -z "$OWNER" ]]     && missing="${missing} --owner"
[[ -z "$REPO" ]]      && missing="${missing} --repo"
[[ -z "$TITLE" ]]     && missing="${missing} --title"
[[ -z "$BODY_FILE" ]] && missing="${missing} --body-file"

if [[ -n "$missing" ]]; then
  printf 'USAGE_ERROR: missing required flags:%s\n' "$missing" >&2
  exit 2
fi

if [[ ! -f "$BODY_FILE" ]]; then
  printf 'USAGE_ERROR: --body-file not found: %s\n' "$BODY_FILE" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Invoke gh issue create
# ---------------------------------------------------------------------------
# Build argument array — body file passed by path, never interpolated.
# gh issue create prints the issue URL to stdout on success.
gh_args=(
  issue create
  --repo "${OWNER}/${REPO}"
  --title "$TITLE"
  --body-file "$BODY_FILE"
)

if [[ -n "$LABEL" ]]; then
  gh_args+=(--label "$LABEL")
fi

gh_exit=0
tmp_out=$(mktemp)
tmp_err=$(mktemp)
trap 'rm -f "$tmp_out" "$tmp_err"' EXIT

gh "${gh_args[@]}" >"$tmp_out" 2>"$tmp_err" || gh_exit=$?

gh_stdout=$(cat "$tmp_out")
gh_stderr_text=$(cat "$tmp_err")

# ---------------------------------------------------------------------------
# Handle gh errors
# ---------------------------------------------------------------------------
if [[ $gh_exit -ne 0 ]]; then
  printf '%s\n' "$gh_stderr_text" >&2
  exit 4
fi

# ---------------------------------------------------------------------------
# Emit issue URL to stdout (URL only, nothing else)
# ---------------------------------------------------------------------------
issue_url=$(printf '%s' "$gh_stdout" | tr -d '\r\n')

if [[ -z "$issue_url" ]]; then
  printf 'gh returned success but no URL in response\n' >&2
  exit 4
fi

printf '%s\n' "$issue_url"
