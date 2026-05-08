#!/usr/bin/env bash
# init.sh — Register an agent's identity in the shared inbox space.
# Fails with exit code 2 if the name is already taken (unless --force is set).
# See init.spec.md for full specification.
set -euo pipefail

usage() {
    cat <<EOF
Usage: init.sh --name <name> [--workspace <path>] [--force]

  --name       Agent's canonical name to register (kebab-case)
  --workspace  Workspace root path (default: \$PWD)
  --force      Reclaim an existing inbox (agent restart); never fails on pre-existing inbox
  --help       Print this help and exit
EOF
}

NAME=''
WORKSPACE="${PWD}"
FORCE=''

while [[ $# -gt 0 ]]; do
    case "$1" in
        --name)      NAME="$2";      shift 2 ;;
        --workspace) WORKSPACE="$2"; shift 2 ;;
        --force)     FORCE='1';      shift   ;;
        --help)      usage; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
done

if [[ -z "$NAME" ]]; then
    echo "Missing required argument: --name" >&2
    exit 1
fi

inbox_dir="${WORKSPACE}/.inbox/${NAME}"
archive_dir="${inbox_dir}/archive"
signal_path="${inbox_dir}/.signal"

if [[ -z "$FORCE" ]]; then
    # Atomic name claim: mkdir fails if directory already exists
    if ! mkdir "$inbox_dir" 2>/dev/null; then
        if [[ -d "$inbox_dir" ]]; then
            echo "inbox '$NAME' is already registered" >&2
            exit 2
        fi
        echo "Failed to create inbox directory: $inbox_dir" >&2
        exit 3
    fi
else
    # --force: create if missing, skip if present
    mkdir -p "$inbox_dir" || {
        echo "Failed to create inbox directory: $inbox_dir" >&2
        exit 3
    }
fi

# Ensure archive directory exists
mkdir -p "$archive_dir" || {
    echo "Failed to create archive directory: $archive_dir" >&2
    exit 3
}

# Write signal file (required on init)
ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
printf '%s\n' "$ts" > "$signal_path" || {
    echo "Failed to write signal file: $signal_path" >&2
    exit 3
}

exit 0
