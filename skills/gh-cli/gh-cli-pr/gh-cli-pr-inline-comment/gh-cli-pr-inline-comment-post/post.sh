#!/usr/bin/env bash
# post.sh — Post a PR inline review comment via gh api.
# Stdout: html_url (single line) on success. Nothing else on stdout.
# Stderr: error messages.
# Exit codes: 0=posted, 2=usage error, 3=line not in diff, 4=gh error.
set -euo pipefail

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
  cat <<'EOF'
Usage: bash post.sh [FLAGS]

Post a single PR inline review comment via gh api.

Required flags:
  --owner <name>       GitHub org or user
  --repo <name>        Repository name
  --pr <num>           PR number
  --commit-sha <sha>   Head commit SHA
  --file <path>        Repo-relative file path
  --line <int>         Absolute line number
  --body-file <path>   Path to a markdown body file (passed to gh by path)

Optional flags:
  --side LEFT|RIGHT    Diff side (default: RIGHT)
  --help, -h           Print this usage and exit 0

Stdout: html_url on success (single LF-terminated line). Nothing else.
Exit:   0=posted  2=usage-error  3=line-not-in-diff  4=gh-error
EOF
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
OWNER=''
REPO=''
PR=''
COMMIT_SHA=''
FILE=''
LINE=''
SIDE='RIGHT'
BODY_FILE=''

while [[ $# -gt 0 ]]; do
  case "$1" in
    --owner)       OWNER="$2";      shift 2 ;;
    --repo)        REPO="$2";       shift 2 ;;
    --pr)          PR="$2";         shift 2 ;;
    --commit-sha)  COMMIT_SHA="$2"; shift 2 ;;
    --file)        FILE="$2";       shift 2 ;;
    --line)        LINE="$2";       shift 2 ;;
    --side)        SIDE="$2";       shift 2 ;;
    --body-file)   BODY_FILE="$2";  shift 2 ;;
    --help|-h)     usage; exit 0 ;;
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
[[ -z "$OWNER" ]]      && missing="${missing} --owner"
[[ -z "$REPO" ]]       && missing="${missing} --repo"
[[ -z "$PR" ]]         && missing="${missing} --pr"
[[ -z "$COMMIT_SHA" ]] && missing="${missing} --commit-sha"
[[ -z "$FILE" ]]       && missing="${missing} --file"
[[ -z "$LINE" ]]       && missing="${missing} --line"
[[ -z "$BODY_FILE" ]]  && missing="${missing} --body-file"

if [[ -n "$missing" ]]; then
  printf 'USAGE_ERROR: missing required flags:%s\n' "$missing" >&2
  exit 2
fi

if ! [[ "$PR" =~ ^[0-9]+$ ]]; then
  printf 'USAGE_ERROR: --pr must be a positive integer, got: %s\n' "$PR" >&2
  exit 2
fi

if ! [[ "$LINE" =~ ^[0-9]+$ ]] || [[ "$LINE" -eq 0 ]]; then
  printf 'USAGE_ERROR: --line must be a positive integer, got: %s\n' "$LINE" >&2
  exit 2
fi

if [[ "$SIDE" != 'LEFT' && "$SIDE" != 'RIGHT' ]]; then
  printf 'USAGE_ERROR: --side must be LEFT or RIGHT, got: %s\n' "$SIDE" >&2
  exit 2
fi

if [[ ! -f "$BODY_FILE" ]]; then
  printf 'USAGE_ERROR: --body-file not found: %s\n' "$BODY_FILE" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Invoke gh api
# ---------------------------------------------------------------------------
# Build argument array — body file passed by path, never interpolated.
# Use gh's embedded --jq to extract html_url; eliminates host jq dependency.
gh_args=(
  api
  --method POST
  "repos/${OWNER}/${REPO}/pulls/${PR}/comments"
  --field "commit_id=${COMMIT_SHA}"
  --field "path=${FILE}"
  --field "line=${LINE}"
  --field "side=${SIDE}"
  --field "body=@${BODY_FILE}"
  --jq ".html_url // empty"
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
  # Detect line-not-in-diff: HTTP 422 where gh surfaces the line resolution error.
  # gh CLI prints the HTTP status and body to stderr on API errors.
  if printf '%s' "$gh_stderr_text" | grep -qi '422' && \
     printf '%s' "$gh_stderr_text" | grep -qi 'pull_request_review_thread\.line\|could not be resolved\|line is not part of the diff\|not part of the pull request diff'; then
    printf 'line not in diff for side %s (422 from gh api)\n' "$SIDE" >&2
    exit 3
  fi
  # All other gh errors → exit 4.
  printf '%s\n' "$gh_stderr_text" >&2
  exit 4
fi

# ---------------------------------------------------------------------------
# Emit html_url to stdout (URL only, nothing else)
# ---------------------------------------------------------------------------
html_url=$(printf '%s' "$gh_stdout" | tr -d '\r\n')

if [[ -z "$html_url" ]]; then
  printf 'gh returned success but html_url missing in response\n' >&2
  exit 4
fi

printf '%s\n' "$html_url"
