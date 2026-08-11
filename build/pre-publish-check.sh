#!/usr/bin/env bash
# pre-publish-check.sh — Pre-publish validation gate for skills-plugin.
#
# Runs BEFORE the version bump / release tag (wired into tools/publish.ps1, which is
# the actual publish orchestrator — see the call near the top of its PRE-FLIGHT section).
# Prevents the recurrence of two defect classes that previously shipped silently broken
# skills: an unparseable UTF-8-BOM'd SKILL.md, and dead relative-path references left
# behind after a directory rename/removal.
#
# Checks (each SKILL.md found under the target):
#   1. BOM        — UTF-8 BOM (0xEF 0xBB 0xBF) at file start.               BLOCKS.
#   2. Frontmatter — YAML frontmatter parses; `name` + `description` present. BLOCKS.
#   3. Dead-ref   — backticked relative dir-refs (`./topics/`, `lite/`, ...)  WARNS only.
#                   that don't resolve to a real directory alongside the file.
#   4. Inheritance — domain-flavor skills (see DOMAIN_FLAVOR_SKILLS below) declare
#                    a `## Inheritance` section.                             BLOCKS.
#
# Usage:
#   pre-publish-check.sh                 # scan the repo's skills/ root (default)
#   pre-publish-check.sh <dir>           # scan all SKILL.md files under <dir>
#   pre-publish-check.sh <file>          # scan one SKILL.md-like file directly
#                                        #   (checks 1+2 only — 3/4 need the skill's
#                                        #   directory context, which a lone scratch
#                                        #   file copied elsewhere doesn't have)
#
# Exit 0  — no blocking findings.
# Exit 1  — >=1 blocking finding (BOM, frontmatter, or missing Inheritance).
# Exit 2  — target path not found (usage error, not a validation finding).
#
# Every finding prints as one grep-able line: "<TAG>: <file>: <detail>".

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)/skills"

TARGET="${1:-$DEFAULT_ROOT}"

# Skills that declare themselves a domain-flavor extension of a parent spec
# (see skills/spec-writing/SKILL.md "Domain-Flavor Extension") must carry a
# `## Inheritance` section naming that parent. Extend this list as new
# domain-flavor skills are added.
DOMAIN_FLAVOR_SKILLS=(prd-writing)

blocking=0

check_bom() {
    local f="$1"
    local first3
    first3="$(head -c 3 -- "$f" | od -An -tx1 | tr -d ' \t\n')"
    if [ "$first3" = "efbbbf" ]; then
        echo "BOM: $f: UTF-8 BOM at file start — YAML frontmatter parser will skip this file"
        blocking=$((blocking + 1))
    fi
}

check_frontmatter() {
    local f="$1"
    # Normalize CRLF -> LF up front. This repo's checkouts are CRLF on disk
    # (core.autocrlf, no .gitattributes forcing LF); Git-for-Windows' bash/awk/sed
    # happen to strip \r via CRT text-mode translation, but that's a property of
    # that specific binary, not of this script — a WSL bash or a Linux CI runner
    # reads bytes literally and would see "---\r", failing every exact match below.
    # Stripping \r explicitly makes the check correct on any bash.
    local content
    content="$(tr -d '\r' < "$f")"
    local first_line
    first_line="$(printf '%s\n' "$content" | sed -n '1p')"
    if [ "$first_line" != "---" ]; then
        echo "FRONTMATTER-FAIL: $f: file does not start with a '---' frontmatter delimiter"
        blocking=$((blocking + 1))
        return
    fi
    local delim_count
    delim_count="$(printf '%s\n' "$content" | grep -c '^---$')"
    if [ "$delim_count" -lt 2 ]; then
        echo "FRONTMATTER-FAIL: $f: frontmatter block has no closing '---' delimiter"
        blocking=$((blocking + 1))
        return
    fi
    local fm
    fm="$(printf '%s\n' "$content" | awk '/^---$/{c++; next} c==1{print} c==2{exit}')"
    if [ -z "$fm" ]; then
        echo "FRONTMATTER-FAIL: $f: empty frontmatter block"
        blocking=$((blocking + 1))
        return
    fi
    if ! grep -qE '^name:[[:space:]]*\S' <<<"$fm"; then
        echo "FRONTMATTER-FAIL: $f: missing required key 'name'"
        blocking=$((blocking + 1))
    fi
    if ! grep -qE '^description:[[:space:]]*\S' <<<"$fm"; then
        echo "FRONTMATTER-FAIL: $f: missing required key 'description'"
        blocking=$((blocking + 1))
    fi
}

has_dot_segment() {
    # True if any '/'-separated segment of $1 starts with '.' (a hidden/runtime
    # directory, e.g. .hash-record/, .claude/agents/, .github/agents/, .optimization/).
    # Must be called AFTER stripping a leading './' — that prefix means "this
    # directory" (explicit-relative), not "hidden", and is a distinct thing.
    local path="$1" seg
    local IFS='/'
    for seg in $path; do
        case "$seg" in
            .*) return 0 ;;
        esac
    done
    return 1
}

check_dead_refs() {
    local f="$1"
    local dir leaf
    dir="$(dirname -- "$f")"
    # Backticked path-shaped refs ending in '/' (directory refs only — file refs are
    # a different, noisier problem and out of scope for this lower-bar warning check).
    grep -oE '`\.?/?[A-Za-z0-9_-]+(/[A-Za-z0-9_.-]+)*/`' "$f" 2>/dev/null | tr -d '`' | sort -u |
    while IFS= read -r ref; do
        [ -z "$ref" ] && continue
        local clean="${ref#./}"
        # Hidden/runtime-state dirs (.hash-record/, .claude/agents/, .optimization/,
        # etc.) are created on first use, not shipped content — excluded. Checked on
        # the CLEANED ref, after stripping an explicit leading './', so "./foo/" and
        # "foo/" are treated identically (both are plain, non-hidden refs).
        if has_dot_segment "$clean"; then continue; fi
        # Refs are commonly relative to the skill's own dir, its parent (sibling
        # sub-skills), or somewhere else under the scanned root (nested skill tree).
        # Only warn if none of those resolve — avoids false positives from ambiguous
        # relative-path conventions across the skill tree.
        if [ -d "$dir/$clean" ]; then continue; fi
        if [ -d "$dir/../$clean" ]; then continue; fi
        leaf="${clean%/}"
        if find "$SEARCH_ROOT" -type d -iname "$(basename -- "$leaf")" 2>/dev/null | grep -q .; then continue; fi
        echo "DEAD-REF (warn): $f: references '$ref' — directory not found (checked alongside file, parent, and search root)"
    done
}

check_inheritance() {
    local f="$1"
    local dir base flavor
    dir="$(dirname -- "$f")"
    base="$(basename -- "$dir")"
    for flavor in "${DOMAIN_FLAVOR_SKILLS[@]}"; do
        if [ "$base" = "$flavor" ]; then
            if ! grep -q '^## Inheritance' -- "$f"; then
                echo "INHERITANCE-MISSING: $f: domain-flavor skill '$base' has no '## Inheritance' section"
                blocking=$((blocking + 1))
            fi
        fi
    done
}

is_publish_ignored() {
    # True if $1 (a path under $TARGET) sits inside a top-level dir listed in
    # $TARGET/.publish-ignore. That file lives in the source repo and lists
    # skills excluded from publishing — they must not block or pollute the gate.
    # Comparison is lowercase to match publish.ps1's case-insensitive set.
    local rel="${1#"$TARGET"/}"
    local top="${rel%%/*}"
    top="$(printf '%s' "$top" | tr '[:upper:]' '[:lower:]')"
    local d
    for d in ${PUBLISH_IGNORED[@]+"${PUBLISH_IGNORED[@]}"}; do
        [ "$top" = "$d" ] && return 0
    done
    return 1
}

if [ -f "$TARGET" ]; then
    check_bom "$TARGET"
    check_frontmatter "$TARGET"
elif [ -d "$TARGET" ]; then
    SEARCH_ROOT="$TARGET"
    PUBLISH_IGNORED=()
    if [ -f "$TARGET/.publish-ignore" ]; then
        # `|| [ -n "$line" ]` keeps a final line that lacks a trailing newline;
        # BOM strip + lowercase align this parser with publish.ps1's
        # (Get-Content + OrdinalIgnoreCase) semantics.
        while IFS= read -r line || [ -n "$line" ]; do
            line="${line#$'\xEF\xBB\xBF'}"
            line="${line%%#*}"
            line="${line//[$' \t\r']/}"
            [ -n "$line" ] && PUBLISH_IGNORED+=("$(printf '%s' "$line" | tr '[:upper:]' '[:lower:]')")
        done < "$TARGET/.publish-ignore"
    fi
    examined=0
    # find runs relative to the target so a dot-segment ANCESTOR of the target
    # (e.g. an install under a dot-dir) cannot prune the whole walk; only
    # dot-paths inside the target are skipped.
    while IFS= read -r rel; do
        f="$TARGET/${rel#./}"
        is_publish_ignored "$f" && continue
        examined=$((examined + 1))
        check_bom "$f"
        check_frontmatter "$f"
        check_dead_refs "$f"
        check_inheritance "$f"
    done < <(cd "$TARGET" && find . -type f -name 'SKILL.md' -not -path '*/.*' | sort)
    if [ "$examined" -eq 0 ]; then
        echo "EMPTY-SCAN: $TARGET: no SKILL.md files examined — refusing to report PASS on zero coverage"
        blocking=$((blocking + 1))
    fi
else
    echo "ERROR: target not found: $TARGET" >&2
    exit 2
fi

echo "---"
if [ "$blocking" -gt 0 ]; then
    echo "pre-publish-check: REJECTED — $blocking blocking finding(s) (see above)"
    exit 1
fi
echo "pre-publish-check: PASS — no blocking findings"
exit 0
