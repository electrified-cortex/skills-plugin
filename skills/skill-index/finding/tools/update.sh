#!/usr/bin/env bash
set -e

root="${1:-}"
key="${2:-}"
value="${3:-}"

if [[ -z "$root" ]]; then
    echo "update: root is required" >&2
    exit 1
fi
if [[ -z "$key" ]]; then
    echo "update: key is required" >&2
    exit 1
fi
if [[ -z "$value" ]]; then
    echo "update: value is required" >&2
    exit 1
fi

cache_dir="${root}/.skill-index"
cache_file="${cache_dir}/lookup.cache"

if [[ ! -d "$cache_dir" ]]; then
    mkdir -p "$cache_dir"
fi
if [[ ! -f "$cache_file" ]]; then
    touch "$cache_file"
fi

new_line="${key}: ${value}"
tmp_file="$(mktemp)"

# Replace existing key line or append
updated=false
while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^${key}: ]]; then
        echo "$new_line" >> "$tmp_file"
        updated=true
    else
        echo "$line" >> "$tmp_file"
    fi
done < "$cache_file"

if [[ "$updated" == false ]]; then
    echo "$new_line" >> "$tmp_file"
fi

mv "$tmp_file" "$cache_file"
