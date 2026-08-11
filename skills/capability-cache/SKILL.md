---
name: capability-cache
description: Short-circuit repeated Copilot CLI invocations by caching model availability locally. Check-then-probe pattern — HIT (including unavailable) skips CLI re-probe entirely. Triggers - check capability cache, cache model availability, probe copilot models, capability cache hit, capability cache miss.
---

Consumer skills call this before invoking any Copilot CLI command. WRITE path invokes `gh copilot models` when no valid cache exists.

Cache File Location:

```text
<cache_root>/<env_key>/copilot-cli/models.yaml
```

Defaults: `cache_root = <repo-root>/.capability-cache/`, `env_key = default`.

Cache Schema:

```yaml
---
operation_kind: copilot-cli/models
result: available | unavailable
models:
  - <model-name>
---
```

Inputs:

| Input | Type | Default | Description |
| --- | --- | --- | --- |
| `cache_root` | path | `<repo-root>/.capability-cache/` | Root dir for cache files |
| `env_key` | string | `default` | Env identifier for namespacing |
| `force_refresh` | boolean | `false` | If true, bypass cache and re-probe |

Outputs:

| Output | Type | Description |
| --- | --- | --- |
| `result` | string | `available` or `unavailable` |
| `models` | list | Model names; empty when unavailable |
| `cache_hit` | boolean | `true` if served from cache, `false` if probed |

Procedure:

READ path (check cache):
1. Compute path: `<cache_root>/<env_key>/copilot-cli/models.yaml`
2. File exists AND `force_refresh` false → read, return `{result, models, cache_hit: true}`. STOP.
3. File missing OR `force_refresh` true → proceed to WRITE path.

WRITE path (probe and populate):
1. Invoke `gh copilot models` (or detection method from copilot-cli skill).
2. Command succeeds → parse model list, set `result: available`, `models: [<list>]`.
3. Command fails (not found, auth error, any non-zero exit) → set `result: unavailable`, `models: []`.
4. Create `<cache_root>/<env_key>/copilot-cli/` if it doesn't exist.
5. Write cache file.
6. Return `{result, models, cache_hit: false}`.

Invalidation:
Erase cache file manually to force re-probe on next call. No TTL.

Rules:
MUST NOT invoke Copilot CLI when cache HIT exists (unless `force_refresh: true`).
`unavailable` IS a valid HIT — don't re-probe on `unavailable`.
Cache files are local only — do NOT commit them (add `.capability-cache/` to `.gitignore`).
Corrupt or unparseable cache file → treat as MISS, proceed to WRITE path.
CLI probe fails → cache `unavailable`, return gracefully. Do NOT throw or halt.

Footguns:

F1 — `unavailable` cached indefinitely:
`unavailable` entry persists if env later gains working `gh` CLI or valid auth. Cache won't self-clear. Fix: pass `force_refresh: true` or delete `<cache_root>/<env_key>/copilot-cli/models.yaml`.

F2 — Corrupted cache treated as MISS:
Corrupt file silently falls through to WRITE path; no error surfaced. Only observable signal: `cache_hit: false` when warm cache expected.

Dependencies:
`gh` CLI on PATH (optional — absence is a valid `unavailable` result).
Read/write access to `cache_root`.
`.capability-cache/` must be gitignored in consuming repo.

Related: `copilot-cli` (consumer), `hash-record` (content-hash-keyed store — different substrate, not used here).
