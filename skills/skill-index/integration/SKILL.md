---
name: integration
description: Wire a skill-index cascade into an agent's context: place the index pointer, write the discovery mandate, enforce demand loading, and verify keyword quality. Triggers - integrate skill index, set up skill discovery, wire skill index, add index to agent, skill index setup.
---

---

## Integration Procedure

### Step 1: Confirm the Scoped Index Exists

Verify the agent has a scoped `skill.index` at its agent directory or a subdirectory. This must not be the workspace-level skills root.

If the index does not exist, build it first using the `skill-index-building` skill.

### Step 2: Determine the Correct Context Injection Point

Determine whether the platform re-reads the agent configuration file at every session start and after every context-window reset:

- **If yes** (the file is always active): place the index pointer and mandate in the agent configuration file (e.g., `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`).
- **If no** (the file is read once at startup only): also inject the pointer and mandate via a supplemental mechanism the platform guarantees survives resets (hook output, persistent system prompt, API system field).

The index pointer and mandate must be present in context at all times, including after compaction or session restart.

### Step 3: Write the Index Pointer and Overlay Reference

Add to the context injection artifact:

```text
Skill index: <path-to-skill.index>
Skill index overlay: <path-to-skill.index.md>
```

Both paths must be resolvable from the agent's working directory or be absolute. The index pointer must point to `skill.index` directly; the overlay reference must point to `skill.index.md` directly.

### Step 4: Write the Discovery Mandate

Add the mandate immediately after the index pointer in the same injection artifact. Use imperative language. Two sentences maximum: the first instructs the scan, the second instructs loading on match.

Conformant example (situational routing with raw-index fallback, per R28):

```text
On every task, match the operator's words or your current situation to an entry in your skill index overlay; load the matching skill's content before proceeding. If no overlay entry matches, substring-scan the raw skill.index as a fallback.
```

Non-conformant examples (do not use):

```text
Consider checking the skill index before responding.
It may be helpful to look up skills in your index.
You should probably check the skill index.
```

The mandate must apply to every task — clarifying questions, small requests, and routine tasks are not exempt.

### Step 5: Verify Runtime Behavior

Confirm the agent does the following at runtime:

1. On receiving any task, matches the operator's words or current situation to a section in the overlay first. If a section matches, loads the full skill content before responding.
2. If no overlay section matches, substring-scans the raw `skill.index` as a fallback.
3. Does not skip the scan or the overlay check for any reason.
4. On a keyword match: reads the full skill content before responding. Announces: `"Using [skill name] to [brief description of action]."` The announcement must be visible to the user or operator.
5. On no match in either overlay or raw index: proceeds without loading any skill content.
6. On missing or unreadable index or overlay: proceeds, notes the issue in output, does not halt.
7. On stale index (stamp absent or invalid): may use the index; notes `"Skill index may be outdated (stamp absent or invalid)."` in output.
8. Does not cache skill content across turns — reloads whenever a match identifies the skill as relevant to the current turn.

### Step 6: Verify Index Scope

Confirm the agent's `skill.index` enumerates only skills within the agent's operational domain. Skills irrelevant to the agent's role must not appear.

Each agent type maintains its own scoped index:

- Curator — governance, documentation, task management skills.
- Worker — execution, implementation, build skills.
- Overseer — orchestration, delegation, monitoring skills.
- Sentinel — security, compliance, monitoring skills.

### Step 7: Verify Keyword Quality

For every entry in the agent's `skill.index`, verify:

- At least three keywords in addition to the entry key.
- Keywords are natural-language phrases (how a user would describe the need, not the technical name).
- No keyword duplicates the entry key verbatim.
- At least one keyword is a multi-word phrase (two or more words).
- No keyword consists solely of the technical skill name with punctuation removed, or is an unchanged camelCase/kebab-case identifier.

---

## Error Handling

| Condition | Action |
| --- | --- |
| `skill.index` missing | Note in output, proceed without skill matching, do not halt |
| `skill.index` unreadable | Note in output, proceed without skill matching, do not halt |
| Match found, skill content missing | Note in output, proceed without skill, do not halt |
| Multiple matches (ambiguous) | Apply `skill-index-crawling` rules first. If still ambiguous, load all candidates sequentially |
| Index stamp absent or invalid | Note stale state in output, use index for matching |
| Discovery mandate absent after reset | Attempt reload from context injection artifact. If still absent, note in output ("Discovery mandate not found; skill scanning disabled for this session"), proceed, do not halt |

---

## Conformance Checklist

An integration is conformant when all of the following are satisfied:

- One scoped index pointer present in reset-surviving injection (R1–R4).
- Overlay reference present in the same injection alongside the pointer (R27).
- Discovery mandate uses situational routing language referencing the overlay (R28).
- Agent scans overlay first, falls back to raw index substring scan (R28).
- Skill content loads only on match, not at startup (R14–R17).
- Agent announces matched skill to immediate consumer before acting (R26).
- Index scoped to agent's operational domain (R18–R20).
- All index entries meet keyword quality requirements (R21–R24).
- Overlay sections are trigger-shaped, not description-shaped (R29).

---

## Common Failures

**Mandate only in a file that does not survive resets** — Agent stops checking skills after compaction.
Fix: Confirm the platform re-reads the config file after resets. If not, add mandate to a supplemental reset-surviving injection.

**Index pointer scoped to full skills tree root** — Keyword matching is noisy; irrelevant skills match.
Fix: Create a per-agent scoped `skill.index` referencing only role-relevant skills.

**Keywords that duplicate the entry key verbatim** — No additional surface coverage.
Fix: Replace verbatim duplicates with synonyms, paraphrases, or related phrases.

**Skill content pre-loaded at startup** — Violates demand loading.
Fix: Read `skill.index` only at startup. Load `SKILL.md` only on a keyword match.

**Mandate in README or design docs** — Agents do not read documentation at every turn.
Fix: Place mandate in an injected context artifact — config file, system prompt, hook output.

---

## Related

- `skill-index` — root router; cascade system overview
- `building` — how to build or rebuild the `skill.index`
- `auditing` — validates structural integrity and keyword quality
- `crawling` — keyword-match algorithm and crawl resolution