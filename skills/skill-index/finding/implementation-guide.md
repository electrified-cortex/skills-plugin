# Skill Index Finding — Implementation Guide

How to implement the finder so that it meets the token-cost requirements in the spec. This document is for implementers building or updating `instructions.txt`; it is not normative.

---

## Core Token-Cost Problem

The cache is a flat file. If the agent reads the entire file and scans for a key, it burns tokens proportional to file size. A 200-entry cache costs 200 lines of tokens on every lookup — worse than no cache at all.

The solution: never let the agent parse the file. Use a script to filter it and return only the matching line (or nothing). The agent calls one script → receives one line → done. Token cost is constant regardless of cache size.

---

## Lookup Mechanism

The `finding/` directory ships a helper script: `lookup.ps1`.

```
lookup.ps1 <root> <query>
```

Outputs one of:
- `hit: <path>` — key found, path verified on disk
- `stale: <old-path>` — key found, path no longer exists
- `miss` — key not in cache
- `url: <url>` — key found, value is a URL (always valid)

The script handles normalization, file creation, and hit verification. The agent's instructions tell it to call this script as the first step — zero file reads by the agent.

### Why a script over agent-driven grep

- Script runs in OS process: reads cache at OS speed, not token speed
- Script normalizes the query deterministically (same code every time)
- Script returns 1 line; agent processes 1 line
- Script handles edge cases (missing file, stale entry) without branching the agent's logic

---

## Agent Flow (instructions.txt pattern)

```
1. Call lookup.ps1 <root> <query>
   hit:   → return "hit: <path>". Done.
   url:   → return "hit: <url>". Done.
   stale: → proceed to step 2 (crawl), then call update.ps1 to replace stale entry
   miss:  → proceed to step 2 (crawl)

2. Invoke crawling sub-skill: need=<normalized-key> root=<root>
   hit:   → call update.ps1 <root> <normalized-key> <path>; return "crawled: <path>"
   miss:  → return "not-found: <query>"
           → append "suggest-register: <key> — not in index; add + rebuild if skill exists"
```

This is 1 script call on a hit, 1 script call + 1 crawl + 1 script call on a miss. Minimum achievable.

---

## Helper Scripts

Two scripts live in `finding/tools/`:

### `lookup.ps1 <root> <query>`

1. Normalize `<query>` → key (lowercase, spaces→hyphens, strip non-alnum-hyphen)
2. Create `.skill-index/` and `lookup.cache` if absent
3. `Select-String -Pattern "^<key>:" "<root>/.skill-index/lookup.cache"` — O(1) token output
4. Parse result:
   - No match → output `miss`
   - Match, value starts with `http` → output `url: <value>`
   - Match, value is file path, `Test-Path` → output `hit: <path>`
   - Match, value is file path, no `Test-Path` → output `stale: <old-path>`

### `update.ps1 <root> <key> <value>`

1. Read `lookup.cache`
2. Replace line starting with `<key>:` if present, else append
3. Write back
4. Outputs nothing (silent on success, error message on failure)

---

## Cache Format

`.skill-index/lookup.cache`:

```
dispatch: /abs/path/to/dispatch/SKILL.md
skill-writing: /abs/path/to/skill-writing/SKILL.md
paiv: /abs/path/to/plan-audit-implement-verify/SKILL.md
```

- One entry per line
- Key: normalized skill name
- Value: absolute path or https URL
- No header, no blank lines
- Matches `skill.index` key-value format for visual consistency

---

## Normalization Rules

These rules apply inside `lookup.ps1` and must match what `instructions.txt` tells the agent to use when passing the query to crawling:

1. Lowercase the entire string
2. Replace runs of whitespace with `-`
3. Strip all characters that are not `[a-z0-9-]`
4. Strip leading and trailing `-`

Examples:
- `"Dispatch Skill"` → `dispatch-skill`
- `"plan/audit"` → `planaudi`... wait: strip `/` → `planaudit` → but that drops intent. Better: replace `/` with `-` before stripping → `plan-audit`

Revised rule: replace `/`, `_`, `.`, and whitespace with `-` before stripping other non-alnum characters.

---

## Tier and Dispatch

The finder is Haiku tier (`fast-cheap`). The `SKILL.md` stub must specify `<tier> = fast-cheap`. This is the primary reason the sub-skill exists: Haiku costs a fraction of Sonnet for a lookup that requires no reasoning.

---

## Suggested Test Cases for Verify Phase

- Cache hit, path exists → returns `hit: <path>`, no crawl invoked
- Cache stale, crawl hit → returns `stale-updated: <path>`, cache updated
- Cache miss, crawl hit → returns `crawled: <path>`, cache written
- Cache miss, crawl miss → returns `not-found: <query>`, registration suggestion present, cache not written
- Cache miss, lookup.cache absent → cache created, treated as miss
- Large cache (100+ entries) → hit resolves in constant time (script, not agent scan)
