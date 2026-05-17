#!/usr/bin/env bash
# create.sh — Open a pull request via gh pr create.
# Stdout: PR URL (single line) on success. Nothing else on stdout.
# Stderr: error messages.
# Exit codes: 0=created, 2=usage error, 4=gh error.
set -euo pipefail

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
  cat <<'EOF'
Usage: bash create.sh [FLAGS]

Open a pull request via gh pr create.

Required flags:
  --owner <name>       GitHub org or user
  --repo <name>        Repository name
  --base <branch>      Base branch (e.g., main)
  --title <text>       PR title
  --body-file <path>   Path to a markdown body file (passed to gh by path)

Optional flags:
  --label <labels>     Comma-separated label names
  --draft              Create as draft PR
  --help, -h           Print this usage and exit 0

Stdout: PR URL on success (single LF-terminated line). Nothing else.
Exit:   0=created  2=usage-error  4=gh-error
EOF
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
OWNER=''
REPO=''
BASE=''
TITLE=''
BODY_FILE=''
LABEL=''
DRAFT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --owner)      OWNER="$2";     shift 2 ;;
    --repo)       REPO="$2";      shift 2 ;;
    --base)       BASE="$2";      shift 2 ;;
    --title)      TITLE="$2";     shift 2 ;;
    --body-file)  BODY_FILE="$2"; shift 2 ;;
    --label)      LABEL="$2";     shift 2 ;;
    --draft)      DRAFT=1;        shift   ;;
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
[[ -z "$BASE" ]]      && missing="${missing} --base"
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
# Invoke gh pr create
# ---------------------------------------------------------------------------
# Build argument array — body file passed by path, never interpolated.
# gh pr create prints the new PR URL to stdout on success.
gh_args=(
  pr create
  --repo "${OWNER}/${REPO}"
  --base "$BASE"
  --title "$TITLE"
  --body-file "$BODY_FILE"
)

if [[ -n "$LABEL" ]]; then
  gh_args+=(--label "$LABEL")
fi

if [[ $DRAFT -eq 1 ]]; then
  gh_args+=(--draft)
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
# Emit PR URL to stdout (URL only, nothing else)
# ---------------------------------------------------------------------------
pr_url=$(printf '%s' "$gh_stdout" | tr -d '\r\n')

if [[ -z "$pr_url" ]]; then
  printf 'gh returned success but no URL in response\n' >&2
  exit 4
fi

printf '%s\n' "$pr_url"
