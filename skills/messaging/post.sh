#!/usr/bin/env bash
# post.sh — Post a message to another agent's inbox.
# See post.spec.md for full specification.
set -euo pipefail

usage() {
    cat <<EOF
Usage: post.sh --from <name> --to <name> --subject <text> --body <text> [--workspace <path>]

  --from       Posting agent's canonical name (kebab-case)
  --to         Recipient agent's canonical name (kebab-case)
  --subject    Short description of message intent
  --body       Message body text
  --workspace  Workspace root path (default: \$PWD)
  --help       Print this help and exit
EOF
}

FROM=''
TO=''
SUBJECT=''
BODY=''
WORKSPACE="${PWD}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --from)      FROM="$2";      shift 2 ;;
        --to)        TO="$2";        shift 2 ;;
        --subject)   SUBJECT="$2";   shift 2 ;;
        --body)      BODY="$2";      shift 2 ;;
        --workspace) WORKSPACE="$2"; shift 2 ;;
        --help)      usage; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
done

# Validate required args
missing=()
[[ -z "$FROM" ]] && missing+=(--from)
[[ -z "$TO" ]]   && missing+=(--to)
[[ -z "$BODY" ]] && missing+=(--body)
if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Missing required argument(s): ${missing[*]}" >&2
    exit 1
fi

if [[ "$FROM" == "$TO" ]]; then
    echo "Cannot post to own inbox: --from and --to are both '$FROM'" >&2
    exit 1
fi

# Resolve paths
inbox_dir="${WORKSPACE}/.inbox/${TO}"
archive_dir="${inbox_dir}/archive"
signal_path="${inbox_dir}/.signal"

# Ensure inbox and archive directories exist
mkdir -p "$archive_dir" || { echo "Failed to create inbox directory: $archive_dir" >&2; exit 2; }

# Generate timestamp
ts=$(date -u '+%Y%m%dT%H%M%SZ')
ts_full=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

# Generate CSPRNG nonce (8 hex chars) with collision retry
max_retries=10
msg_path=''
for ((i = 0; i < max_retries; i++)); do
    nonce=$(head -c 4 /dev/urandom | xxd -p)
    filename="${ts}-${nonce}.json"
    candidate="${inbox_dir}/${filename}"
    if [[ ! -e "$candidate" ]]; then
        msg_path="$candidate"
        break
    fi
done
if [[ -z "$msg_path" ]]; then
    echo "Failed to generate unique filename after ${max_retries} attempts" >&2
    exit 2
fi

# Assemble JSON message
# Use printf to safely escape values (replace \ and ")
body_escaped=$(printf '%s' "$BODY" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g')
from_escaped=$(printf '%s' "$FROM" | sed 's/\\/\\\\/g; s/"/\\"/g')
if [[ -n "$SUBJECT" ]]; then
    subject_escaped=$(printf '%s' "$SUBJECT" | sed 's/\\/\\\\/g; s/"/\\"/g')
    content="{\"from\":\"${from_escaped}\",\"sent\":\"${ts_full}\",\"subject\":\"${subject_escaped}\",\"body\":\"${body_escaped}\"}"
else
    content="{\"from\":\"${from_escaped}\",\"sent\":\"${ts_full}\",\"body\":\"${body_escaped}\"}"
fi

# Atomic write: temp file, then rename into inbox
tmp=$(mktemp)
printf '%s' "$content" > "$tmp"
mv "$tmp" "$msg_path"

# Write signal file (failure tolerated)
printf '%s\n' "$ts" > "$signal_path" 2>/dev/null || true

exit 0
