# Curator Index Reference Implementation

**Source file:** `agents/curator/skill.index.md` (relative to the consuming agent's workspace root)

**What changed from the current file:**

- All sections rewritten as trigger-shaped prose (when to load, not what the skill does)
- `[op]` or `[self]` marker added to every section heading
- Every section now expresses at least 3 distinct trigger surfaces
- Operator-triggered sections lead with operator-quoted phrases
- Agent-self-triggered sections lead with plain imperatives
- H1 updated to follow canonical title convention
- Preamble added to establish routing convention once (per R30)
- Path-style section keys (`## skills/operator-information-handling`) converted to short canonical keys (`## operator-information-handling`)

**Quality reference:** The Overseer's `skill.index.md` was the pre-existing reference. This retrofit matches or exceeds that quality level across all sections.

---

## Full Proposed Replacement `skill.index.md`

```markdown
# Curator — skill index

Match the operator's words (or your current situation) to an entry below, then load that skill. If no entry matches, use skill-index-crawling to walk the shared library.

## operator-information-handling [op]

When the operator gives any instruction, question, or request — load this first. Use it before responding to any operator message, including short clarifications and single-line commands. Nothing the operator says may be dropped without an actionable result.

## session-lifecycle [self]

At session startup, after a context compaction, or when recovering from a crash or unexpected restart. Also when the operator asks about session continuity, prior context, or what was active before the interruption.

## audit-scan [op]

When the operator asks to scan a directory for integrity, check stamps, or flag unstamped files. Also when you are preparing to audit a skill tree and need to verify SHA-256 stamp coverage before starting.

## curator-periodic-optimization [self]

At the start of a daily optimization cycle: drain the memory parking lot, route items to their final destinations, and clean stale state. Also when the operator asks to "run the daily optimization" or "tidy up the memory system."

## skill-index-crawling [self]

When no entry in this overlay matches your current situation or the operator's request. Always reach for this before improvising or giving up — it walks the full shared skill library.

## dispatch [self]

Before dispatching any subagent — read this to choose the right agent type (subagent, background, foreground) and model. Also when the operator asks which agent or model to use for a given task.

## compression [self]

Before writing any overlay section or skill content, run a compression pass on the draft. Also when a document, session note, or output has grown past the context budget, or when a downstream consumer reports the content is too long.

## spec-writing [op]

When the operator asks to "write a spec", "draft requirements", "spec out this feature", or "define what this should do before we build it." Also when creating a new work item that requires formal requirements before implementation begins.

## spec-auditing [op]

When the operator asks to "audit this spec", "review the spec for correctness", "check for drift", or "validate before we implement." Also before stamping any spec or promoting it from draft to active.

## skill-auditing [op]

When the operator asks to "audit this skill", "check skill quality", "evaluate for drift", or "validate the skill against current practice." Also when a skill's stamp is absent or the skill has not been reviewed since last update.

## audit-reporting [self]

After completing any audit (spec, skill, tool, or code) — format and write the report before closing the audit. Also when the operator asks for an audit report in a specific format or asks to write up findings.

## hash-stamp [self]

After writing or updating any artifact that requires a `.sha256` companion. Also when the operator asks to verify stamp integrity, detect stamp drift, or update a stale stamp. Load before `audit-scan` to understand the stamp write side.

## markdown-hygiene [op]

When the operator asks to "clean up this markdown", "fix the formatting", "normalize the document", or "make this consistent." Also before writing any skill or spec that will be stamped — formatting must be canonical before the stamp is applied.

## skill-index-building [op]

When the operator asks to "rebuild the skill index", "update the skill index", "add a new index node", or "regenerate the overlay." Also when a new skill directory has been added and its parent index node is stale.

## skills/ [self]

When skill-index-crawling comes up empty. Browse the shared workspace skill library directly only as a last resort — after local overlay, local raw index, and crawling have all failed to find a match.
```

---

## Full Proposed Replacement `skill.index` (Raw Index)

```
## operator-information-handling [op]
triggers: operator gives an instruction | operator asks a question | any operator message received | nothing the operator says may be dropped | before responding to operator
path: ../../skills/electrified-cortex/operator-information-handling/SKILL.md

## session-lifecycle [self]
triggers: session startup | after context compaction | recovering from crash | unexpected restart | what was active before interruption
path: ../../skills/electrified-cortex/session-lifecycle/SKILL.md

## audit-scan [op]
triggers: scan directory for integrity | check stamps | flag unstamped files | verify SHA-256 stamp coverage | audit skill tree
path: ../../skills/electrified-cortex/audit-scan/SKILL.md

## curator-periodic-optimization [self]
triggers: daily optimization cycle | drain memory parking lot | route items to final destinations | run the daily optimization | tidy up the memory system
path: ../../skills/electrified-cortex/curator-periodic-optimization/SKILL.md

## skill-index-crawling [self]
triggers: no entry above matches | skill not in local index | find a skill by phrase | unknown task type | fall through to shared library
path: ../../skills/electrified-cortex/skill-index/skill-index-crawling/SKILL.md

## dispatch [self]
triggers: before dispatching any subagent | choose agent type | which model to use | right agent for delegated work | foreground vs background agent
path: ../../skills/electrified-cortex/dispatch/SKILL.md

## compression [self]
triggers: before writing any overlay section | document past context budget | session too long | output too long to process | trim before sending
path: ../../skills/electrified-cortex/compression/SKILL.md

## spec-writing [op]
triggers: write a spec | draft requirements | spec out this feature | define what this should do | formal requirements before implementation
path: ../../skills/electrified-cortex/spec-writing/SKILL.md

## spec-auditing [op]
triggers: audit this spec | review the spec for correctness | check for drift | validate before we implement | stamp this spec
path: ../../skills/electrified-cortex/spec-auditing/SKILL.md

## skill-auditing [op]
triggers: audit this skill | check skill quality | evaluate for drift | validate the skill against current practice | skill stamp is absent
path: ../../skills/electrified-cortex/skill-auditing/SKILL.md

## audit-reporting [self]
triggers: after completing any audit | format and write audit report | audit findings writeup | write up findings | report in specific format
path: ../../skills/electrified-cortex/audit-reporting/SKILL.md

## hash-stamp [self]
triggers: writing artifact that requires sha256 companion | verify stamp integrity | detect stamp drift | update a stale stamp | after writing or updating any artifact
path: ../../skills/electrified-cortex/hash-stamp/SKILL.md

## markdown-hygiene [op]
triggers: clean up this markdown | fix the formatting | normalize the document | make this consistent | formatting must be canonical before stamp
path: ../../skills/electrified-cortex/markdown-hygiene/SKILL.md

## skill-index-building [op]
triggers: rebuild the skill index | update the skill index | add a new index node | regenerate the overlay | new skill directory added and parent index is stale
path: ../../skills/electrified-cortex/skill-index/skill-index-building/SKILL.md

## skills/ [self]
triggers: skill-index-crawling came up empty | browse shared workspace skill library | all other discovery paths exhausted | last resort skill search | local overlay and crawling both failed
path: ../../skills/SKILL.index
```

---

## Annotations

The following notes explain non-obvious decisions in the retrofit:

**`operator-information-handling [op]`** — Every operator message is a trigger, so the trigger-shaped prose says exactly that: load before any operator response. This is the only skill that must fire universally.

**`session-lifecycle [self]`** — This is agent-self-triggered: the Curator recognizes a restart/compaction state and loads the skill. The operator does not normally ask for "session continuity."

**`audit-scan [op]`** — Mixed trigger: operator asks for integrity scan, but the Curator also loads it before starting an audit tree walk. Listed `[op]` because the dominant trigger is operator-initiated.

**`curator-periodic-optimization [self]`** — Primarily a scheduled self-trigger (daily cycle). The Curator does not need an operator prompt to recognize this state.

**`dispatch [self]`** — Self-triggered: the Curator recognizes it is about to delegate and loads the skill preemptively. Not normally prompted by an operator saying "use dispatch."

**`skills/ [self]`** — Preserved as a last-resort browse pointer following the Overseer pattern. Listed as `[self]` because the agent self-recognizes "all other discovery paths exhausted."
