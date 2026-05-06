# Startup Mandate Template

Ready-to-paste discovery mandate blocks for agent startup-context.md or CLAUDE.md. Choose the version appropriate for the agent's token budget. Both versions must be placed in a context injection artifact that survives context-window resets (R2, R9).

---

## Version 1 — Concise (4 lines

Use for agents where every token counts (e.g., Worker, Sentinel). Minimal but fully conformant with R5–R9 and R27–R28.

```text
Skill index: <path-to-skill.index>
Skill overlay: <path-to-skill.index.md>

If the skill index file does not exist, invoke `skill-index-building` before proceeding. A missing index is not a normal operating state — build it once, then follow the standard mandate.

Before responding to any task, match the operator's words or your current situation to an entry in your skill overlay. If a match is found, read the full skill content before proceeding. If no overlay entry matches, substring-scan the raw skill.index as a fallback.
```

**Substitution guide:**

- `<path-to-skill.index>`: absolute or working-directory-relative path to the agent's scoped `skill.index` file. Example: `agents/worker/skill.index`
- `<path-to-skill.index.md>`: same directory, `.md` extension. Example: `agents/worker/skill.index.md`

---

## Version 2 — Expanded (8 lines

Use for agents that coordinate other agents or handle ambiguous operator input (e.g., Curator, Overseer, Deputy). Includes examples of what "matching your situation" means, reducing false negatives after context resets.

```text
Skill index: <path-to-skill.index>
Skill overlay: <path-to-skill.index.md>

If the skill index file does not exist, invoke `skill-index-building` before proceeding. A missing index is not a normal operating state — build it once, then follow the standard mandate. A newly cloned worktree or freshly created agent role will not have a pre-built index. The first run should build it; subsequent runs use the existing index.

Before responding to any task, match the operator's words or your current situation to an entry in your skill overlay (skill.index.md). If a section matches, read the full skill content before proceeding. If no overlay section matches, substring-scan the raw skill.index as a fallback.

Matching examples:
- Operator says "spawn a worker" → match spawn-worker [op] → load skill
- Operator says "merge this PR" → match copilot-exhaustion [op] → load skill
- You are about to dispatch a subagent → match dispatch [self] → load skill
- You observe an idle cycle → match scan-tasks [self] → load skill
- No entry matches → scan raw skill.index by substring → load on match; proceed without skill if still no match
```

**Substitution guide:**

- Replace `<path-to-skill.index>` and `<path-to-skill.index.md>` with the agent's actual paths.
- Replace the four matching examples with entries drawn from the agent's own overlay sections. Use one `[op]` example and one `[self]` example at minimum.
- Keep the final "No entry matches" example unchanged — it is required to establish the fallback behavior.

---

## Placement Requirements

1. Place the mandate in the agent's primary configuration file (e.g., `CLAUDE.md`, `AGENTS.md`, system prompt). If the platform re-reads this file on every context-window reset, this is sufficient.
2. If the platform reads the configuration file only at initial load (not after resets), also inject the mandate via a supplemental reset-surviving mechanism (hook output, API system-prompt field, `additionalContext` in a compact hook).
3. The mandate must appear before any task queue or session state content. Agents must encounter it before processing any dequeued task.
4. Do not place the mandate only in session logs, README files, design documents, or similar passive artifacts. Agents do not re-read documentation at every turn.

---

## Anti-patterns (do not use

The following forms are non-conformant and must not appear in the mandate:

| Non-conformant | Why |
| --- | --- |
| "Consider checking the skill index before responding." | Guidance language, not imperative — banned by R6 |
| "It may be helpful to look up skills in your index." | Optional framing — agent may skip; banned |
| "You should probably check the skill index." | Hedged — agent may skip; banned |
| "If you feel it is relevant, consult the skill overlay." | Conditional on agent judgment — banned |
| "Scan the skill.index.md only for complex tasks." | Exempts tasks by complexity — banned by R7 |

---

## Verification Checklist

After placing the mandate, confirm all of the following:

- [ ] Mandate is in a context injection artifact that survives context-window resets
- [ ] Mandate references both the raw index path and the overlay path
- [ ] Mandate instructs overlay-first routing, raw-index-fallback second
- [ ] Mandate is imperative (no "consider", "may", "should probably")
- [ ] Mandate applies to every task with no exemptions
- [ ] Load-on-match consequence is explicitly stated
- [ ] At least one `[op]` and one `[self]` matching example is present (expanded version)
