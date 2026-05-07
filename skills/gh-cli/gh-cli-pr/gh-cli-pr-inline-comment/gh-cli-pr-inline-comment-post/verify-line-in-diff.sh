#!/usr/bin/env bash
# verify-line-in-diff.sh — Check whether a PR diff line is commentable
# Usage: verify-line-in-diff.sh OWNER REPO PR_NUMBER FILE_PATH LINE_NUMBER SIDE
# Outputs: IN_DIFF | NOT_IN_DIFF ranges:... | FILE_NOT_IN_DIFF | USAGE:... | API_ERROR:...
# Exit codes: 0=in_diff  1=not_in_diff  2=file_not_in_diff  3=usage_error  4=api_error
set -e

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  cat <<'USAGE'
Usage: verify-line-in-diff.sh OWNER REPO PR_NUMBER FILE_PATH LINE_NUMBER SIDE

Check whether LINE_NUMBER is within a commentable hunk range for FILE_PATH
in a GitHub pull request diff.

Arguments:
  OWNER        GitHub org or user name
  REPO         Repository name
  PR_NUMBER    Integer PR number
  FILE_PATH    Repo-relative path (e.g. src/foo.ts)
  LINE_NUMBER  Absolute line number to check
  SIDE         RIGHT (additions/context) or LEFT (deletions)

Output (stdout, one line):
  IN_DIFF                       Line is in a hunk range; safe to comment
  NOT_IN_DIFF ranges:<r1>,...   Line is not commentable; valid ranges listed
  FILE_NOT_IN_DIFF              File has no changes in this PR
  API_ERROR: <reason>           gh pr diff call failed
  USAGE: ...                    Bad arguments

Exit codes:
  0   IN_DIFF
  1   NOT_IN_DIFF
  2   FILE_NOT_IN_DIFF
  3   Bad arguments
  4   API error
USAGE
  exit 0
fi

# ---------------------------------------------------------------------------
# Argument validation
# ---------------------------------------------------------------------------
if [ "$#" -lt 6 ]; then
  echo "USAGE: verify-line-in-diff.sh OWNER REPO PR_NUMBER FILE_PATH LINE_NUMBER SIDE"
  exit 3
fi

OWNER="$1"
REPO="$2"
PR_NUMBER="$3"
FILE_PATH="$4"
LINE_NUMBER="$5"
SIDE="$6"

if [ "$SIDE" != "RIGHT" ] && [ "$SIDE" != "LEFT" ]; then
  echo "USAGE: SIDE must be RIGHT or LEFT, got: $SIDE"
  exit 3
fi

if ! echo "$LINE_NUMBER" | grep -qE '^[0-9]+$'; then
  echo "USAGE: LINE_NUMBER must be a positive integer, got: $LINE_NUMBER"
  exit 3
fi

if ! echo "$PR_NUMBER" | grep -qE '^[0-9]+$'; then
  echo "USAGE: PR_NUMBER must be a positive integer, got: $PR_NUMBER"
  exit 3
fi

# ---------------------------------------------------------------------------
# Fetch patch
# ---------------------------------------------------------------------------
PATCH=$(gh pr diff "$PR_NUMBER" --repo "$OWNER/$REPO" --patch 2>&1) || {
  echo "API_ERROR: $PATCH" >&2
  echo "API_ERROR: gh pr diff failed"
  exit 4
}

# ---------------------------------------------------------------------------
# Parse hunk headers for FILE_PATH
# Hunk pattern: @@ -OLD[,OLD_LEN] +NEW[,NEW_LEN] @@
# Compact form: absent LEN means 1. LEN=0 means that side has no lines (skip).
# ---------------------------------------------------------------------------
in_file=0
found_file=0
ranges=()
DIFF_HEADER="diff --git a/$FILE_PATH b/$FILE_PATH"
HUNK_RE='^@@ -([0-9]+)(,([0-9]+))? [+]([0-9]+)(,([0-9]+))? @@'

while IFS= read -r line; do
  if [[ "$line" == diff\ --git\ * ]]; then
    if [[ "$line" == "$DIFF_HEADER" ]]; then
      in_file=1
      found_file=1
    else
      in_file=0
    fi
    continue
  fi

  if [[ "$in_file" -eq 1 ]] && [[ "$line" =~ $HUNK_RE ]]; then
    OLD_START="${BASH_REMATCH[1]}"
    OLD_LEN="${BASH_REMATCH[3]:-1}"
    NEW_START="${BASH_REMATCH[4]}"
    NEW_LEN="${BASH_REMATCH[6]:-1}"

    if [ "$SIDE" = "RIGHT" ] && [ "$NEW_LEN" -gt 0 ]; then
      ranges+=("$NEW_START $((NEW_START + NEW_LEN - 1))")
    elif [ "$SIDE" = "LEFT" ] && [ "$OLD_LEN" -gt 0 ]; then
      ranges+=("$OLD_START $((OLD_START + OLD_LEN - 1))")
    fi
  fi
done <<< "$PATCH"

# ---------------------------------------------------------------------------
# Result
# ---------------------------------------------------------------------------
if [ "$found_file" -eq 0 ]; then
  echo "FILE_NOT_IN_DIFF"
  exit 2
fi

range_strs=()
for r in "${ranges[@]+"${ranges[@]}"}"; do
  start="${r% *}"
  end="${r#* }"
  range_strs+=("$start-$end")
  if [ "$LINE_NUMBER" -ge "$start" ] && [ "$LINE_NUMBER" -le "$end" ]; then
    echo "IN_DIFF"
    exit 0
  fi
done

joined=$(IFS=,; echo "${range_strs[*]+"${range_strs[*]}"}")
echo "NOT_IN_DIFF ranges:$joined"
exit 1
