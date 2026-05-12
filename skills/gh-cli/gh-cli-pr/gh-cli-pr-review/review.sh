#!/usr/bin/env bash
# review.sh — Submit or dismiss a pull request review via gh pr review.
# Stdout: PR URL (single line) on success. Nothing else on stdout.
# Stderr: error messages.
# Exit codes: 0=submitted, 2=usage error, 4=gh error.
set -euo pipefail

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
  cat <<'EOF'
Usage: bash review.sh [FLAGS]

Submit or dismiss a pull request review via gh pr review.

Required flags:
  --owner <name>       GitHub org or user
  --repo <name>        Repository name
  --pr <num>           PR number
  --decision <value>   One of: approve, request-changes, comment, dismiss

Conditional flags:
  --body-file <path>   Path to a markdown body file (required for request-changes
                       and comment; optional for approve and dismiss)
  --review-id <id>     Review ID (required for dismiss)

Optional flags:
  --help, -h           Print this usage and exit 0

Stdout: PR URL on success (single LF-terminated line). Nothing else.
Exit:   0=submitted  2=usage-error  4=gh-error
EOF
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
OWNER=''
REPO=''
PR=''
DECISION=''
BODY_FILE=''
REVIEW_ID=''

while [[ $# -gt 0 ]]; do
  case "$1" in
    --owner)      OWNER="$2";     shift 2 ;;
    --repo)       REPO="$2";      shift 2 ;;
    --pr)         PR="$2";        shift 2 ;;
    --decision)   DECISION="$2";  shift 2 ;;
    --body-file)  BODY_FILE="$2"; shift 2 ;;
    --review-id)  REVIEW_ID="$2"; shift 2 ;;
    --help|-h)    usage; exit 0 ;;
    *)
      printf 'USAGE_ERROR: unknown flag: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Validation — required flags
# ---------------------------------------------------------------------------
missing=''
[[ -z "$OWNER" ]]    && missing="${missing} --owner"
[[ -z "$REPO" ]]     && missing="${missing} --repo"
[[ -z "$PR" ]]       && missing="${missing} --pr"
[[ -z "$DECISION" ]] && missing="${missing} --decision"

if [[ -n "$missing" ]]; then
  printf 'USAGE_ERROR: missing required flags:%s\n' "$missing" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Validation — --decision enum
# ---------------------------------------------------------------------------
case "$DECISION" in
  approve|request-changes|comment|dismiss) ;;
  *)
    printf 'USAGE_ERROR: --decision must be one of: approve, request-changes, comment, dismiss; got: %s\n' "$DECISION" >&2
    exit 2
    ;;
esac

# ---------------------------------------------------------------------------
# Validation — --pr is a positive integer
# ---------------------------------------------------------------------------
if ! [[ "$PR" =~ ^[0-9]+$ ]]; then
  printf 'USAGE_ERROR: --pr must be a positive integer, got: %s\n' "$PR" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Validation — conditional flags
# ---------------------------------------------------------------------------
if [[ "$DECISION" == 'request-changes' || "$DECISION" == 'comment' ]]; then
  if [[ -z "$BODY_FILE" ]]; then
    printf 'USAGE_ERROR: --body-file is required when --decision is %s\n' "$DECISION" >&2
    exit 2
  fi
fi

if [[ "$DECISION" == 'dismiss' ]]; then
  if [[ -z "$REVIEW_ID" ]]; then
    printf 'USAGE_ERROR: --review-id is required when --decision is dismiss\n' >&2
    exit 2
  fi
fi

if [[ -n "$BODY_FILE" && ! -f "$BODY_FILE" ]]; then
  printf 'USAGE_ERROR: --body-file not found: %s\n' "$BODY_FILE" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Map --decision to gh flag
# ---------------------------------------------------------------------------
case "$DECISION" in
  approve)          GH_FLAG='--approve' ;;
  request-changes)  GH_FLAG='--request-changes' ;;
  comment)          GH_FLAG='--comment' ;;
  dismiss)          GH_FLAG='--dismiss' ;;
esac

# ---------------------------------------------------------------------------
# Build gh argument array — body file passed by path, never interpolated
# ---------------------------------------------------------------------------
gh_args=(
  pr review "$PR"
  --repo "${OWNER}/${REPO}"
  "$GH_FLAG"
)

if [[ -n "$REVIEW_ID" ]]; then
  gh_args+=(--review-id "$REVIEW_ID")
fi

if [[ -n "$BODY_FILE" ]]; then
  gh_args+=(--body-file "$BODY_FILE")
fi

# ---------------------------------------------------------------------------
# Invoke gh pr review
# ---------------------------------------------------------------------------
gh_exit=0
tmp_out=$(mktemp)
tmp_err=$(mktemp)
trap 'rm -f "$tmp_out" "$tmp_err"' EXIT

gh "${gh_args[@]}" >"$tmp_out" 2>"$tmp_err" || gh_exit=$?

gh_stderr_text=$(cat "$tmp_err")

if [[ $gh_exit -ne 0 ]]; then
  printf '%s\n' "$gh_stderr_text" >&2
  exit 4
fi

# ---------------------------------------------------------------------------
# gh pr review emits no URL on success — retrieve via gh pr view
# ---------------------------------------------------------------------------
pr_url=''
url_exit=0
pr_url=$(gh pr view "$PR" --repo "${OWNER}/${REPO}" --json url --jq '.url' 2>&1) || url_exit=$?

if [[ $url_exit -ne 0 ]]; then
  printf '%s\n' "$pr_url" >&2
  exit 4
fi

pr_url=$(printf '%s' "$pr_url" | tr -d '\r\n')

if [[ -z "$pr_url" ]]; then
  printf 'gh pr view returned success but no URL in response\n' >&2
  exit 4
fi

printf '%s\n' "$pr_url"
