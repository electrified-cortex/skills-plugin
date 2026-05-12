#!/usr/bin/env bash
# post.sh — Post a general PR comment via gh pr comment.
# Stdout: comment URL (single line) on success. Nothing else on stdout.
# Stderr: error messages.
# Exit codes: 0=posted, 2=usage error, 4=gh error.
set -euo pipefail

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
  cat <<'EOF'
Usage: bash post.sh [FLAGS]

Post a general PR comment via gh pr comment.

Required flags:
  --owner <name>       GitHub org or user
  --repo <name>        Repository name
  --pr <num>           PR number
  --body-file <path>   Path to a markdown body file (passed to gh by path)

Optional flags:
  --help, -h           Print this usage and exit 0

Stdout: comment URL on success (single LF-terminated line). Nothing else.
Exit:   0=posted  2=usage-error  4=gh-error
EOF
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
OWNER=''
REPO=''
PR=''
BODY_FILE=''

while [[ $# -gt 0 ]]; do
  case "$1" in
    --owner)      OWNER="$2";     shift 2 ;;
    --repo)       REPO="$2";      shift 2 ;;
    --pr)         PR="$2";        shift 2 ;;
    --body-file)  BODY_FILE="$2"; shift 2 ;;
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
[[ -z "$PR" ]]        && missing="${missing} --pr"
[[ -z "$BODY_FILE" ]] && missing="${missing} --body-file"

if [[ -n "$missing" ]]; then
  printf 'USAGE_ERROR: missing required flags:%s\n' "$missing" >&2
  exit 2
fi

if ! [[ "$PR" =~ ^[0-9]+$ ]]; then
  printf 'USAGE_ERROR: --pr must be a positive integer, got: %s\n' "$PR" >&2
  exit 2
fi

if [[ ! -f "$BODY_FILE" ]]; then
  printf 'USAGE_ERROR: --body-file not found: %s\n' "$BODY_FILE" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Invoke gh pr comment
# ---------------------------------------------------------------------------
# Build argument array — body file passed by path, never interpolated.
# gh pr comment prints the comment URL to stdout on success.
gh_args=(
  pr comment "$PR"
  --repo "${OWNER}/${REPO}"
  --body-file "$BODY_FILE"
)

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
# Emit comment URL to stdout (URL only, nothing else)
# ---------------------------------------------------------------------------
comment_url=$(printf '%s' "$gh_stdout" | tr -d '\r\n')

if [[ -z "$comment_url" ]]; then
  printf 'gh returned success but no URL in response\n' >&2
  exit 4
fi

printf '%s\n' "$comment_url"
