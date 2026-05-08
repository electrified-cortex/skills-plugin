#!/usr/bin/env bash
# drain.sh — Drain all pending messages from an agent's inbox.
# See drain.spec.md for full specification.
set -euo pipefail

usage() {
    cat <<EOF
Usage: drain.sh --inbox <name> [--workspace <path>]

  --inbox      Agent name whose inbox to drain (kebab-case)
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
archive_dir="${inbox_dir}/archive"

# Empty inbox is not an error
if [[ ! -d "$inbox_dir" ]]; then
    exit 0
fi

# Ensure archive dir exists
mkdir -p "$archive_dir" || { echo "Failed to create archive directory: $archive_dir" >&2; exit 2; }

# Helper: archive a claimed file, optionally collect content into messages array
drain_claimed() {
    local claimed_path="$1"
    local orig_name="$2"
    local output_content="$3"   # "true" or "false"
    local archive_dest="${archive_dir}/${orig_name}"
    local content=''

    if [[ "$output_content" == "true" ]]; then
        content=$(cat "$claimed_path" 2>/dev/null) || {
            echo "Failed to read '$claimed_path'" >&2
        }
    fi

    mv "$claimed_path" "$archive_dest" 2>/dev/null || {
        echo "Failed to archive '$claimed_path' to '$archive_dest'" >&2
    }

    if [[ "$output_content" == "true" && -n "$content" ]]; then
        messages+=("$content")
    fi
}

# Pass 1: unclaimed *.json files (sorted ascending)
messages=()
while IFS= read -r -d '' filepath; do
    filename=$(basename "$filepath")

    claimed_path="${filepath}.claimed"
    if mv "$filepath" "$claimed_path" 2>/dev/null; then
        drain_claimed "$claimed_path" "$filename" "true"
    fi
    # else: lost the race or file gone — skip silently
done < <(find "$inbox_dir" -maxdepth 1 -name '*.json' -print0 | sort -z)

# Pass 2: leftover *.json.claimed from a prior crashed run — archive without re-outputting
while IFS= read -r -d '' filepath; do
    filename=$(basename "$filepath")
    orig_name="${filename%.claimed}"
    drain_claimed "$filepath" "$orig_name" "false"
done < <(find "$inbox_dir" -maxdepth 1 -name '*.json.claimed' -print0 | sort -z)

# Output JSON array
if [[ ${#messages[@]} -eq 0 ]]; then
    printf '[]
'
else
    first=true
    printf '['
    for msg in "${messages[@]}"; do
        if [[ "$first" == "true" ]]; then
            first=false
        else
            printf ','
        fi
        printf '%s' "$msg"
    done
    printf ']
'
fi

exit 0
