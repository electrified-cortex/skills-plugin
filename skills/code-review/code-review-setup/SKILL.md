---
name: code-review-setup
description: Preflight readiness check — verify the host environment can run code-review. Inline. Returns structured ready / not-ready report with remediation. Triggers - check code review setup, verify code review environment, code review prerequisites, preflight check, setup readiness check.
---

Inline sub-skill of `code-review`. Run once per environment before first code-review claim. Read-only, idempotent, fast (<5s).

Inputs: `target_repo` (optional, default cwd).

Output:

```yaml
overall: ready | not-ready
checks:
  - name: <id>
    status: ready | not-ready | not-applicable
    detail: <what was tested and found>
    remediation: <required action when not-ready; null otherwise>
```

`overall` is `ready` only when every check is `ready` or `not-applicable`.

## Required checks

| Check | Verifies |
| --- | --- |
| `git-installed` | `git --version` returns a version string. |
| `git-hash-object` | `git hash-object --stdin` accepts content and returns a 40-char SHA-1. |
| `code-reviews-dir-writable` | `target_repo` permits creation of `.code-reviews/`. |
| `code-reviews-gitignored` | `.code-reviews/` listed in `<target_repo>/.gitignore`. Read-only — don't modify .gitignore. |
| `swarm-reachable` | The `swarm` skill is discoverable from the host's skill index. |

Optional informational checks (e.g., copilot-cli) mark `not-applicable` rather than fail overall.

## Remediation rule

Every `not-ready` check produces remediation specific enough to act on without further investigation. Vague remediation ("fix permissions", "see docs") is insufficient — the rule is not satisfied.

## Don'ts

Don't write files. Don't throw, exit, or refuse output on `not-ready` — return the report; host decides. Don't fail overall on optional checks. Don't include vague remediation. Don't dispatch code-review. Don't chain checks (each is independent).

## Iteration safety

No caching. The check runs end-to-end every invocation. Stale-result risk outweighs re-run cost.

Related: `code-review`, `swarm`.
