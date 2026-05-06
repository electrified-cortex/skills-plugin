# Canonical Skill Index Format Specification

This document defines the authoritative format for all skill index artifacts. Every agent's `skill.index` (raw index) and `skill.index.md` (overlay) must conform to this spec. The Overseer's overlay is the pre-existing reference implementation of trigger-shaped prose; the Curator's retrofitted overlay (see `curator-index-reference.md`) serves as the reference for mid-complexity agents.

---

## 1. Raw Index Format (`skill.index`)

Each entry occupies exactly two lines — a key line and a triggers line — followed by one blank line before the next entry.

```
## <key>
triggers: <phrase> | <phrase> | <phrase>
path: <relative-path-to-SKILL.md>
```

### Rules

- `## <key>`: H2 heading. Key is the skill's short name — no path prefix, no extension, no trailing slash. Must be unique within the file.
- `triggers:`: pipe-separated list of natural-language phrases. Minimum three phrases. No phrase may duplicate the key verbatim. At least one phrase must contain two or more words. Phrases are lower-case; no trailing period.
- `path:`: relative path to the skill's `SKILL.md`, resolvable from the index file's directory. Use forward slashes. Do not include anchor fragments.
- One blank line between entries. No blank lines within an entry.
- Entries sorted byte-lexicographically on the key. Self-entry (key `.`) always first when present.
- Sub-node entries (key ending `/`) share the sort space with regular keys; `/` is 0x2F.

### Markers in the key

Append a marker directly after the key text, separated by a space, on the `## <key>` line:

| Marker | Meaning |
| --- | --- |
| `[op]` | Operator-triggered — a human or orchestrating agent explicitly asks for this |
| `[self]` | Agent-self-triggered — the agent recognizes its own state, operational context, or transition (e.g., idle cycle start, task completion, pre-flight check) and invokes the skill without being asked by an operator |

Every entry carries exactly one marker. If a skill is naturally invocable both by operator request AND by agent self-observation, use the dominant trigger mode and express the secondary mode as additional trigger phrases.

### Combo node (skill that is also a namespace)

When a skill name also serves as a namespace for sub-skills, create two entries: one for the parent skill itself (with its path) and one for each sub-skill. Use a trailing `/` suffix on the namespace entry's key to denote it is also a branch: `## skill-index/` with `path:` pointing to the index file of the sub-tree, and a separate `## skill-index-building` entry for the leaf skill.

### Empty index

An index with zero skills in scope must still be a valid file with a header section. The Entries section contains the literal placeholder: `(no entries — this agent has no locally scoped skills)`. Readers must treat this as an empty, valid index, not an error.

### Example entries

```
## spawn-worker [op]
triggers: spawn a worker | no workers available | queue is backed up | add capacity | fleet is empty | worker is dead or stuck
path: ../../skills/- fleet/spawn-worker/SKILL.md

## scan-tasks [self]
triggers: idle cycle start | before verification pass | check queue depth | any tasks pending | what is pending
path: ../../skills/task-engine/scan-tasks/SKILL.md

## compression [self]
triggers: markdown too long | context budget exceeded | compress this session | trim before sending | overlay compression pass
path: ../../skills/electrified-cortex/compression/SKILL.md

## copilot-exhaustion [op]
triggers: is the PR ready | merge this PR | Copilot left comments | address the review | request a review | PR number
path: ../../skills/- GitHub/copilot-exhaustion/SKILL.md

## skill-index-crawling [self]
triggers: no entry above matches | skill not in local index | find a skill by phrase | unknown task type | fall through to shared library
path: ../../skills/electrified-cortex/skill-index/skill-index-crawling/SKILL.md
```

---

## 2. Overlay Format (`skill.index.md`)

The overlay is the human-readable trigger map loaded into agent context on every reset. It is the primary discovery surface (R27). The raw index is the substring-match fallback.

### Structure

```markdown
# <Agent Name> — skill index

Match the operator's words (or your current situation) to an entry below, then load that skill.

## <key> [op]

<1–3 trigger-shaped sentences using operator-quoted phrases.>

## <key> [self]

<1–3 trigger-shaped sentences using plain imperatives.>
```

### Rules

- H1 title identifies the agent and the artifact type.
- Optional preamble after H1 (one to two sentences) establishes the routing convention. Preferred phrasing: "Match the operator's words (or your current situation) to an entry below, then load that skill."
- One `## <key>` section per entry, same order as raw index. Key includes the `[op]` or `[self]` marker.
- Each section body: one to three sentences. No lists. No code blocks. No nav mechanics. No explanation of what the skill does — only when to load it.
- Operator-triggered `[op]` sections: lead with operator-quoted phrases in double quotes. Cover the natural synonyms an operator would use.
- Agent-self-triggered `[self]` sections: lead with plain imperatives ("Before dispatching any subagent", "At the start of every idle cycle", "When the scanner returns a batch").
- Every section must express at least three distinct triggers — either as quoted phrases, named situations, or plain imperatives — across its prose.
- Sections must not describe what the skill does. "This skill dispatches a new worker process" is description-shaped and non-conformant.
- Must pass a compression pass before write (per `skill-index-building`).

### Trigger-shaped vs. description-shaped (examples)

**Non-conformant (description-shaped):**

```
## compression
Compress markdown sessions, notes, or docs to reduce token budget.
```

This says what the skill does, not when to load it. An agent cannot route to this from a situation.

**Conformant (trigger-shaped, self-triggered):**

```
## compression [self]
Before writing any overlay section, run a compression pass. Also use when a session or doc has grown past the context budget, or when a downstream consumer reports the output is too long to process.
```

**Non-conformant (description-shaped):**

```
## spawn-worker
Handles spawning new worker processes.
```

**Conformant (trigger-shaped, operator-triggered):**

```
## spawn-worker [op]
When the operator says "spawn a worker", "add capacity", "the queue is backed up", or "no workers available". Also when you observe an empty fleet and a queued task that has no free Worker to claim it.
```

---

## 3. Trigger Phrase Guidelines

### What makes a good trigger phrase

A good trigger phrase answers: "What would an operator say, or what situation would the agent observe, that signals this skill is needed?"

| Quality | Example |
| --- | --- |
| Operator-quoted natural speech | "merge this PR", "queue is backed up" |
| Self-observed agent state | "idle cycle start", "before verification pass" |
| Synonym of the key in plain English | "fleet is empty" (for spawn-worker) |
| Action the agent is about to take | "before dispatching any subagent" |
| Named domain event | "Worker reported DONE", "scanner returned a batch" |

### What makes a bad trigger phrase

| Defect | Example | Why |
| --- | --- | --- |
| Verbatim key repetition | `spawn-worker` as a phrase for `spawn-worker` | No additional surface; banned by R23 |
| Technical identifier unchanged | `skillIndexCrawling`, `skill-index-crawling` | Not natural language; no synonym value |
| Single-word-only set | `scan`, `compress`, `review` | Ambiguous across skills; banned by R24 |
| Description masquerading as trigger | "used for sealing verified tasks" | Tells what, not when |
| Internal mechanics phrase | "checks skill.index.sha256 stamp" | Exposes implementation detail; not operator-visible |

### Minimum phrase count and composition

- Raw index `triggers:` field: minimum 3 phrases, at least 1 multi-word phrase.
- Overlay section: minimum 3 distinct trigger surfaces (quoted phrases, named situations, or imperatives) expressed in prose across 1–3 sentences.

---

## 4. Field Reference Table

| Field | Location | Required | Format | Notes |
| --- | --- | --- | --- | --- |
| `## <key>` | Both | Yes | Short skill name, no path/ext | H2 heading |
| `[op]` / `[self]` marker | Both | Yes | Appended to key heading | One per entry; dominant trigger mode |
| `triggers:` | Raw index | Yes | Pipe-separated phrases | Min 3; min 1 multi-word; no verbatim key |
| `path:` | Raw index | Yes | Relative path to SKILL.md | Forward slashes; no anchor |
| `tags:` | Raw index | Optional | Comma-separated tag words | For future filtering; not yet required |
| `agent-scope:` | Raw index | Optional | Agent name(s) | When a skill is only valid for specific agents |
| Section body | Overlay | Yes | 1–3 trigger-shaped sentences | No description; no lists; compression-required |

### Migration

Existing indexes built against `skill-index-integration` v1.3.1 may use `agent:` instead of `role:`. Readers must accept both field names. Builders must emit `role:`. The `agent:` field name is deprecated as of this spec.

---

## 5. Complete Example Entries (4 entries, two types)

### Raw index entries

```
## copilot-exhaustion [op]
triggers: is the PR ready | merge this PR | Copilot left comments | address the review | another round of review | request a review
path: ../../skills/- GitHub/copilot-exhaustion/SKILL.md

## spawn-worker [op]
triggers: spawn a worker | no workers available | queue is backed up | add capacity | fleet is empty | worker is dead or stuck | picking up a queued task with no free worker
path: ../../skills/- fleet/spawn-worker/SKILL.md

## scan-tasks [self]
triggers: idle cycle start | before verification pass | any tasks done | what is pending verification | queue depth check
path: ../../skills/task-engine/scan-tasks/SKILL.md

## skill-index-crawling [self]
triggers: no entry above matches | unknown task type | find a skill by phrase | fall through to shared library | local index came up empty
path: ../../skills/electrified-cortex/skill-index/skill-index-crawling/SKILL.md
```

### Corresponding overlay sections

```markdown
## copilot-exhaustion [op]

When the operator says "is the PR ready?", "merge this PR", "Copilot left comments", "address the review", or "request a review." Also when you are about to merge your own PR and have not checked Copilot's review annotations.

## spawn-worker [op]

When the operator says "spawn a worker", "no workers available", "queue is backed up", "add capacity", or "fleet is empty." Also when you observe a queued task and no free Worker to claim it.

## scan-tasks [self]

At the start of every idle cycle and before any verification pass — never assume the review queue is empty without scanning. Also when the operator asks "any tasks done?" or "what's pending verification?"

## skill-index-crawling [self]

When no entry in this overlay matches your current situation or the operator's request. Always reach for this before giving up or improvising — it walks the full shared skill library.
```
