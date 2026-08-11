#!/usr/bin/env bash
set -e

root="${1:-}"
query="${2:-}"

if [[ -z "$root" ]]; then
    echo "lookup: root is required" >&2
    exit 1
fi
if [[ -z "$query" ]]; then
    echo "lookup: query is required" >&2
    exit 1
fi

# Normalize query to cache key
key="${query,,}"                          # lowercase
key="${key//[\/\\_[:space:]]/-}"          # / \ _ whitespace → -
key="${key//[^a-z0-9-]/}"                 # strip non-[a-z0-9-]
key="${key#-}"; key="${key%-}"            # strip leading/trailing -

cache_dir="${root}/.skill-index"
cache_file="${cache_dir}/lookup.cache"

# Ensure cache directory and file exist
if [[ ! -d "$cache_dir" ]]; then
    mkdir -p "$cache_dir"
fi
if [[ ! -f "$cache_file" ]]; then
    touch "$cache_file"
    echo "miss"
    exit 0
fi

# Grep-style single-line lookup — returns one line or empty
line=$(grep -m 1 "^${key}:" "$cache_file" 2>/dev/null || true)

if [[ -z "$line" ]]; then
    echo "miss"
    exit 0
fi

value="${line#*: }"

if [[ "$value" =~ ^https?:// ]]; then
    echo "url: $value"
    exit 0
fi

if [[ -e "$value" ]]; then
    echo "hit: $value"
else
    echo "stale: $value"
fi
