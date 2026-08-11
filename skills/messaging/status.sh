#!/usr/bin/env bash
# status.sh — Report pending message count in an agent's inbox.
# Lightweight read-only probe. Does not claim, read, or modify any file.
# See status.spec.md for full specification.
set -euo pipefail

usage() {
    cat <<EOF
Usage: status.sh --inbox <name> [--workspace <path>]

  --inbox      Agent name whose inbox to check (kebab-case)
  --workspace  Workspace root path (default: \$PWD)
  --help       Print this help and exit
EOF
}

INBOX=''
WORKSPACE="${PWD}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --inbox)     INBOX="$2";     shift 2 ;;
        --workspace) WORKSPACE="$2"; shift 2 ;;
        --help)      usage; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
done

if [[ -z "$INBOX" ]]; then
    echo "Missing required argument: --inbox" >&2
    exit 1
fi

inbox_dir="${WORKSPACE}/.inbox/${INBOX}"

count=0
if [[ -d "$inbox_dir" ]]; then
    count=$(find "$inbox_dir" -maxdepth 1 -name '*.json' | wc -l) || {
        echo "Failed to read inbox directory: $inbox_dir" >&2
        exit 2
    }
    count="${count// /}"  # trim whitespace from wc output
fi

ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
printf '[%s]: %s messages waiting\n' "$ts" "$count"

exit 0
