---
name: spec-writing
description: Write precise, testable, auditable specification documents with explicit scope, stable terminology, and enforceable requirements. Triggers - write a spec, create specification, draft spec document, new spec file, spec document.
---

Write specs: clear, complete, enforceable, internally consistent, externally auditable.

Purpose: define intent precisely, testably, auditably.

Scope: when writing spec or derived target doc governed by source spec. All scope must be explicitly declared.
Not for: non-spec docs (design notes, ADRs, READMEs), auditing (see spec-auditing), retroactive application without re-audit.

Definitions:
Spec: normative doc defining rules, requirements, constraints, expected behavior.
Atomic: requirement expressing exactly one testable condition; can't decompose further.
Testable: satisfaction verifiable from doc text alone without external judgment.
Normative: defines requirements/constraints/behavior; strictly enforceable.
Descriptive: explains context/intent; mustn't contradict normative content.
Exploratory: captures ideas, tradeoffs, open questions; may contain ambiguity.
Informational: notes, examples, references.
Mandatory language: must, shall, required.
Prohibited language: must not, shall not.
Guidance language: should, recommended.
Optional language: may, optional.

Content Modes:
Every section must be classified as one of:
Normative: defines requirements, constraints, or behavior. Strictly enforceable.
Descriptive: explains context or intent. Mustn't contradict normative content.
Exploratory: captures ideas, tradeoffs, or open questions. May contain ambiguity.
Informational: notes, examples, or references.
Only Normative sections are strictly enforceable. Any statement affecting behavior must be placed in Normative section.

Requirements:
Define behavior or constraints. Use enforceable language. Be internally consistent, structurally coherent, externally auditable. No reliance on implied intent. State all required behavior explicitly. Every requirement verifiable. Each requirement in one canonical location. Define and use terms consistently. Clearly distinguish required, prohibited, guidance, optional behavior.
Required sections:
Purpose: defines intent
Scope: defines boundaries
Definitions: defines all key terms
Requirements: atomic, testable rules
Constraints: limits and prohibitions
Behavior: system behavior including edge cases
Content Modes: operational modes defined (inline, dispatch, etc.) with trigger/behavior distinctions
Defaults and Assumptions: explicit defaults only
Error Handling: defined failure behavior
Precedence Rules: conflict resolution
Don'ts: explicit exclusions
After section list, include a Section Classification table: columns = Section, Mode. Mode values: Normative, Descriptive, Informational.

Each requirement must be atomic (one testable condition only), testable (verifiable from doc text alone), and unambiguous.
Use subject-verb-object form. Name actor, artifact acted upon, and trigger condition. Two clear sentences preferred over one dense nested clause.
Dense or compressed phrasing in normative requirement is defect. Reader must parse any single requirement on first read without re-scanning surrounding text.
For derived targets: map every normative requirement to source spec. Mappings one-to-one or one-to-many. Unmapped = Unauthorized Additions.

Constraints:
Spec mustn't contain:
vague terms
implied behavior
hidden requirements
contradictions
duplicate rules
subjective language

Normative requirements mustn't be:
embedded in examples
implied in descriptive text
introduced in exploratory sections

For derived targets: no new normative requirements, no term redefinition, no scope expansion, no changed constraints/defaults, no new concepts.
If extension is allowed, spec must define where extension is permitted and what constraints apply. Otherwise extension is prohibited.

Domain-Flavor Extension:
Spec permits domain-flavor extension. Derived spec may declare itself domain flavor (e.g., `prd-writing`) and add normative sections specific to its domain, subject to all of:
derived spec includes Inheritance section naming this spec as parent + domain-flavor declaration
derived spec inherits, without contradiction, this spec's Content Modes, normative-language rules, atomicity requirements, and audit gate
additional normative requirements are atomic, testable, use normative language defined here
every additional section classified in Section Classification table using this spec's Content Modes
derived spec mustn't redefine any term defined here, expand scope contrary to this spec, change default or constraint declared here, or override any rule here
derived spec references corresponding audit skill running `spec-auditing` first, then domain-specific checks

Additional requirements in conforming derived spec are VALID EXTENSIONS, not Unauthorized Additions. Traceability applies to requirements restating or specializing parent rule; requirements unique to domain need not trace to parent rule.

Without explicit Inheritance declaration and conformance above, derived-target rules apply unchanged: no new normative requirements permitted.

Behavior:
Statement affects behavior → move to Normative section (see Content Modes). Define behavior including edge cases. State defaults explicitly. Define failure behavior explicitly. Define conflict resolution explicitly. State explicit exclusions.
For derived targets, allowed transforms: reword for clarity, reorganize structure, aggregate related requirements, add descriptive explanations. Preserve meaning of all normative statements.
Validate before accepting: all required sections present, all requirements use normative language, no vague wording, all terms defined, no duplicates, no contradictions, no implicit assumptions.

Output Quality Gate:
Accept only if: all requirements testable, no critical ambiguity, terminology stable, no contradictions, no unauthorized scope expansion.

Defaults and Assumptions:
Only explicit defaults allowed. Ambiguity allowed only in non-normative sections. Assume every requirement will be challenged, every omission detected, every ambiguity flagged.

Error Handling:
Spec containing unresolvable defects is invalid; artifact derivation is blocked until defects are fixed and spec reaches PASS.
Ambiguous normative statement → rewrite.
Behavior-affecting statement outside Normative section → move to Normative section.
Requirement not atomic, testable, or enforceable → rewrite before treating spec as valid or deriving any artifact from it.

Precedence:
Correctness and enforceability over readability. Normative content governs behavior. Non-normative content mustn't introduce hidden requirements. For derived targets, source spec authoritative, target subordinate. Normative statement with multiple reasonable interpretations → invalid, must rewrite.

Derivation Workflow:
Before writing any artifact derived from spec (skill, agent, or tool), spec must pass full audit.

1. Write spec.
2. Dispatch spec-auditor: fast-cheap iterations first, standard for final pass.
3. Fix all findings (including any formatting issues flagged).
4. Re-audit until PASS.
5. Write derived artifact only after PASS.
6. Dispatch appropriate artifact auditor on derived artifact as separate pass.

Completion Gate:
NOT done until `spec-auditing` returns PASS. No exceptions. Never derive artifacts, commit, or hand off without PASS in hand. Receiving FAIL and stopping is a workflow violation.

Skipping spec-auditor pass before writing derived artifact is prohibited.

Don't use descriptive, exploratory, or informational content as substitute for normative requirements. Don't use this skill to justify silent scope expansion. Don't embed normative requirements in examples, descriptive text, or exploratory sections.

Footgun Convention:
Specs may include optional `Footguns` section. Format:
**F#: {title}** — failure mode description.
Why: why it's a footgun.
Mitigation: specific fix (parameter, phrasing, constraint).
Wrong-usage examples anywhere in spec use `ANTI-PATTERN:` prefix.
Canonical reference: `dispatch` skill (F1–F5 with Mitigation: lines and one ANTI-PATTERN: worked example).

Related: `spec-auditing` (verify spec quality), `skill-writing` (write skills from specs), `skill-auditing` (verify skill quality), `markdown-hygiene` (zero-error lint gate)
