---
name: prd-writing
description: Write a Product Requirements Document as a product-layer flavor of a spec. Triggers — write a PRD, draft product requirements, author a PRD, new product requirements document, create PRD.
---

PRD Writing

PRD = spec at product layer. Read `spec-writing` first — it owns base workflow, content modes, quality discipline. This skill records deltas: additional sections, rules, anti-patterns distinguishing PRD from generic spec.

Workflow:
Follow `spec-writing` workflow. PRD-specific changes:
1. Use this skill's required sections list in addition to `spec-writing` base sections.
2. Apply PRD-specific quality rules (outcome over output, binary AC, measurable NFR, Out-of-Scope discipline).
3. Audit with `prd-auditing`, not `spec-auditing`. PRD auditor runs `spec-auditing` first, then PRD-specific checks.

Drafting Order:
Write in order below. Each section anchors next; Summary written last.

1. Problem — what user, customer, or system can't currently do; cost of status quo; who is affected.
2. Users / Personas — audience. For internal-only infrastructure with no end-user, write one explicit exemption sentence and skip rest.
3. Goals and Success Metrics — each Goal is outcome (measurable change), not output (deliverable). Each Goal pairs with ≥1 metric and target/threshold.
4. Out of Scope — adjacent capabilities deliberately excluded. Write BEFORE drafting requirements. Term "Out of Scope" is mandatory; "non-goals" is banned.
5. Functional Requirements — numbered, atomic. One testable condition per req. Each FR carries ≥1 binary AC verifiable from document text alone.
6. Non-Functional Requirements — measurable thresholds: latency, uptime, viewport range, accessibility, compliance. No subjective adjectives.
7. Assumptions, Constraints, Dependencies — external conditions, regulatory/technical limits, upstream/downstream dependencies.
8. Open Questions — unresolved items. Each blocking question names decider and blocking effect, or is marked `non-blocking`.
9. Release / Rollout Notes — launch plan, phasing, feature flags. One line is fine when accurate.
10. Summary — written last. ≤5 sentences. Problem, product, primary outcome.
11. Header — title, author, status (draft / review / approved), version, last-updated date.

Rules:
OUTCOME > OUTPUT. Goal = measurable change in user/customer/system state. ANTI-PATTERN: "Goal: ship new dashboard." Correct: "Goal: reduce time-to-first-insight from 5 min to <30s, measured by session telemetry."
ONE requirement, ONE condition. Split any FR containing "and", "or", or list of behaviors.
BINARY Acceptance Criteria. Each AC is pass/fail and verifiable from document text. Subjective qualifiers prohibited: "fast", "easy", "intuitive", "responsive", "robust", "should feel". Replace each with measurable predicate or remove.
MEASURABLE NFRs. ANTI-PATTERN: "Must be performant." Correct: "p95 response time MUST be ≤200ms under 1000 RPS."
OUT OF SCOPE is mandatory. Enumerate ≥1 explicit exclusion when product has adjacent capability plausibly confused with it.
OPEN QUESTIONS name decider. Blocking question without decider is defect. Resolved questions removed, not annotated.
SUMMARY is short. ≤5 sentences. Written last.
INTERNAL CONSISTENCY. No FR may contradict Out-of-Scope item; no Goal may contradict Constraint.
LIVING DOCUMENT. Update version and date on every material change.

Anti-Patterns:
Sprint backlog masquerading as PRD — tickets with story points aren't PRD.
Wireframes in place of requirements — state required behavior; design owns visuals.
Implementation detail leakage — "Use Redis for caching" is impl; PRD requires cache invalidation behavior.
Multi-clause requirements — split.
Hidden requirements in descriptive prose — move to normative section.
"Non-goals" section — use "Out of Scope".
"Should feel fast" — replace with measurable threshold.

Out-of-Scope Constraints:
PRD MUST NOT contain: impl detail (architecture, APIs, schemas, libraries); market analysis (TAM, competitive landscape); business case argumentation (ROI, headcount); pixel-perfect UX (wireframes, mockups); sprint backlog (tasks, story points); staffing detail (RACI, rosters). Conceptual UX flow descriptions permitted.

Quality Gate:
PRD is ready for review when:
1. All `spec-writing` required sections present, plus PRD additions (Header, Summary, Problem, Users, Goals & Metrics, FRs, NFRs, Out of Scope, Assumptions / Constraints / Dependencies, Open Questions, Release Notes).
2. Every Goal pairs with ≥1 quantified Success Metric.
3. Every FR has ≥1 binary AC.
4. Every NFR states measurable threshold.
5. Out of Scope has ≥1 explicit exclusion when product has adjacent capability.
6. Open Questions ordered with blocking items first; each blocker names decider.
7. No banned terminology.
8. No content from Out-of-Scope Constraints list.
9. Summary ≤5 sentences.
10. Header complete.

Run `prd-auditing` on draft. Skill isn't complete until auditor returns PASS or CLEAN.

Related:
`spec-writing` — parent skill; base workflow and rules
`prd-auditing` — audit gate
`spec-auditing` — runs as first phase of `prd-auditing`
