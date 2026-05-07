# Skill Index Scoping Rules

Defines which skills belong in each agent's index, how to classify shared skills, and when to climb the cascade to a parent index.

---

## Per-Agent Skill Domains

### Summary Table

| Agent | Operational Domain | Should Index | Must Not Index |
| --- | --- | --- | --- |
| Curator | Governance, spec lifecycle, memory routing, curation | Spec authoring/auditing, skill authoring/auditing, hash-stamp, compression, dispatch, session-lifecycle, memory management, operator-information-handling, skill-index-building, skill-index-crawling | Worker execution skills, fleet management, security audit |
| Worker | Task execution, subagent dispatch, build/implement | Task-engine (claim, lifecycle, scan-tasks, task-execution), dispatch, skill-index-crawling | Spec authoring, fleet management, hash-stamp writing, security audit |
| Overseer | Fleet orchestration, verification, task lifecycle closure | Spawn-worker, fleet-management, task-engine (scan-tasks, verification, finalization, lifecycle), copilot-exhaustion, skill-index-crawling | Spec authoring, security audit, memory routing |
| Sentinel | Security audit, compliance, monitoring | Code-review, spec-auditing, tool-auditing, dispatch, skill-index-crawling | Task execution, fleet management, spec authoring, session-lifecycle |
| Deputy | General-purpose support, auditing, analysis | Spec-auditing, skill-auditing, tool-auditing, code-review, compression, dispatch, audit-reporting, hash-stamp, skill-index-crawling | Fleet management, task-engine execution, memory routing |

---

## Per-Agent Notes

### Curator

The Curator owns the spec-to-skill pipeline and memory system. Its index must include every skill involved in authoring, auditing, and compressing artifacts. It also owns the skill-index-building workflow and must index that skill directly.

Skills the Curator should always include:

- `spec-writing` — drafts new work specs
- `spec-auditing` — validates specs before implementation
- `skill-auditing` — evaluates skills for quality and drift
- `audit-reporting` — formats and writes audit reports
- `skill-index-building` — builds or rebuilds index nodes
- `hash-stamp` — writes and verifies `.sha256` companions
- `compression` — required compression pass before overlay writes
- `dispatch` — choose the right subagent model and type
- `session-lifecycle` — session continuity after resets and compactions
- `operator-information-handling` — every operator statement requires an actionable result
- `markdown-hygiene` — fix/clean markdown formatting
- `skill-index-crawling` — fallback to shared skill library

The Curator should NOT index task-engine execution skills (claim-task, task-execution) — those belong to Worker.

### Worker

The Worker is a pure executor. Its index is narrow by design: only the skills required to claim and execute tasks. It dispatches all implementation work to subagents rather than doing it directly, so its skill surface is intentionally minimal.

Skills the Worker should always include:

- `task-execution` — execute accepted tasks via subagent dispatch
- `claim-task` (task-engine) — claim a queued task and move it to active
- `scan-tasks` (task-engine) — scan the queue for available tasks
- `lifecycle` (task-engine) — pipeline stage definitions and role boundaries
- `dispatch` — choose the right subagent model and type
- `skill-index-crawling` — fallback to shared skill library

The Worker must NOT index spec-authoring, skill-building, fleet management, or security audit skills. Its role is execution, not governance.

### Overseer

The Overseer manages the fleet and owns the task lifecycle closure gate (verification, finalization, sealing). It is the only agent that should index fleet management and task verification skills.

Skills the Overseer should always include:

- `spawn-worker` — add a new worker to the fleet
- `fleet-management` — fleet health, scaling, shutdown decisions
- `scan-tasks` (task-engine) — scan review queue before verification
- `verification` (task-engine) — review and close out completed tasks
- `finalization` (task-engine) — seal a verified task with dated archive
- `lifecycle` (task-engine) — pipeline stage definitions and role boundaries
- `copilot-exhaustion` — handle PR review annotation rounds (GitHub operations)
- `skill-index-crawling` — fallback to shared skill library

The Overseer should NOT index spec-authoring, memory routing, or security audit skills.

### Sentinel

The Sentinel is security-and-compliance focused. Its index is narrow: only review and audit skills. It does not execute tasks or manage fleet state.

Skills the Sentinel should always include:

- `code-review` — security-focused review of code changes
- `spec-auditing` — audit specs for security gaps and threat coverage
- `tool-auditing` — review scripts for unsafe patterns and spec conformance
- `dispatch` — choose the right model for analysis tasks
- `skill-index-crawling` — fallback to shared skill library

The Sentinel must NOT index task execution, fleet management, spec authoring, or memory management skills.

### Deputy

The Deputy is a general-purpose support agent: it audits, analyses, and assists other agents on demand. Its index overlaps with both Curator (auditing) and Sentinel (review) but excludes operational execution skills.

Skills the Deputy should always include:

- `spec-auditing` — validate specs for correctness, completeness, and drift
- `skill-auditing` — evaluate skills for quality, accuracy, and drift
- `tool-auditing` — review scripts for correctness, security, and spec conformance
- `code-review` — tiered review of code changes (read-only)
- `compression` — reduce token budget for documents and sessions
- `dispatch` — choose the right agent type and model for delegated work
- `audit-reporting` — format and write audit report output files
- `hash-stamp` — verify stamp integrity or update `.sha256` companions
- `skill-index-crawling` — fallback to shared skill library

The Deputy should NOT index fleet management, task-engine execution, or memory-routing skills.

### Dispatch

The Dispatch agent is a stateless subagent launcher — it selects the right agent type, model, and invocation method for delegated work. Its index is minimal: only skills required to evaluate delegation decisions.

Skills the Dispatch agent should always include:

- `dispatch` `[self]` — invoked by the agent before delegating any task; self-triggered as part of its own workflow, not prompted by operator
- `compression` `[self]` — reduce context before handing off to a subagent; agent-self-triggered when output exceeds budget
- `skill-index-crawling` `[self]` — fallback to shared skill library when no local entry matches

Skills the Dispatch agent may optionally include (depending on role scope):

- `spawn-worker` `[op]` — operator explicitly requests a new worker; operator-triggered
- `fleet-management` `[op]` — operator requests fleet status, scaling, or shutdown decisions; operator-triggered
- `session-lifecycle` `[self]` — agent self-recognizes a restart or compaction and loads continuity context; self-triggered

The Dispatch agent must NOT index task-execution, spec-authoring, or memory-routing skills.

---

## Shared Skills (Every Agent)

The following skills are required in every agent's index regardless of role:

| Skill | Rationale |
| --- | --- |
| `skill-index-crawling` | Required fallback when no local entry matches; cascade exit hatch |
| `dispatch` | Every agent that delegates to subagents needs dispatch guidance |

Note: `dispatch` may be omitted from agents that never delegate work (e.g., a pure read-only Sentinel variant). When in doubt, include it.

---

## Cascade Rule

**When to use a local index entry vs. climbing to the parent:**

1. Check the agent's scoped overlay (`skill.index.md`) first. If a section matches the current situation, load that skill. Stop.
2. If no overlay section matches, substring-scan the agent's raw `skill.index`. If a match is found, load that skill. Stop.
3. If no match is found in the local index, invoke `skill-index-crawling` to walk the shared workspace skill library. `skill-index-crawling` handles cascade descent.
4. Never climb directly to the workspace skills root without going through `skill-index-crawling`. Direct access bypasses match resolution and stamp verification.

**When NOT to climb:**

- Do not add a parent-level skill to a local index just because the skill is available — only include skills within the agent's operational domain (R18–R20).
- Do not index a skill that another agent role exclusively owns (e.g., Worker must not index `spawn-worker`; Overseer must not index `claim-task`).

**When a locally-indexed skill is insufficient:**

If a local skill's content covers the task partially, it may reference a deeper skill in its own `Related` section. Follow that reference directly — this is crawl descent, not cascade climbing.

---

## Boundary Conflicts

When a skill appears relevant to two agents, apply this decision rule:

1. **Trigger mode is the tiebreaker.** If only Overseer operators ever say "spawn a worker", `spawn-worker` belongs in Overseer's index — not in Curator or Worker.
2. **Execution vs. governance split.** Execution skills (`claim-task`, `task-execution`) belong to Worker; governance/closure skills (`verification`, `finalization`) belong to Overseer.
3. **Audit skills belong to auditors.** `spec-auditing`, `skill-auditing`, `tool-auditing` belong to Curator and Deputy, not Worker or Sentinel's exclusive domain.
4. **Shared utility skills** (`compression`, `dispatch`, `hash-stamp`) may appear in multiple agents' indexes if those agents genuinely use them.
