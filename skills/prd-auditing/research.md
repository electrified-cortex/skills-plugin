# PRD Writing Research

Research date: 2026-05-12. Target: inform spec for a `prd-writing` workspace skill.

---

## 1. Canonical PRD

### Definition

A Product Requirements Document (PRD) "defines the purpose, features, and behavior of a product" and "acts as a strategic document that outlines the purpose, features, functionality, and behavior of a product that is going to be developed" [source: https://blog.logrocket.com/product-management/what-is-a-product-requirements-document-prd/]. ProductPlan defines it as "an artifact used in the product development process to communicate what capabilities must be included in a product release to the development and testing teams" [source: https://www.productplan.com/glossary/product-requirements-document].

Productboard frames it as "the working document product managers use to describe what a team should build and why it matters," providing clarity on (1) scope, (2) constraints, (3) acceptance criteria, and (4) expected customer value [source: https://www.productboard.com/blog/product-requirements-document-guide/].

Cross-checking three sources yields a consistent core: the PRD bridges business intent and development execution by specifying *what* a product must do and *why*, without specifying *how* to implement it.

### Standard Sections

Sources agree on a core set with minor variation in naming:

| Section | Description | Consensus |
|---|---|---|
| Problem statement / purpose | Why this exists; the customer/business problem | All sources |
| Target users / personas | Who benefits; segmentation | Most sources |
| Goals and success metrics | Measurable outcomes, KPIs | All sources |
| Features / functional requirements | What the product must do, structured as user stories or numbered requirements | All sources |
| Non-functional requirements | Performance, reliability, security, scalability | Most sources |
| Non-goals / out-of-scope | Explicit scope boundaries | Most sources |
| Assumptions, constraints, dependencies | External conditions and limits | Most sources |
| Open questions | Unresolved items | Many sources |
| Release / rollout notes | Launch considerations | Some sources |

The altexsoft.com breakdown also adds "UX flow and design notes" and "system/environment requirements" as standard sections [source: https://www.altexsoft.com/blog/product-requirements-document/]. The LogRocket three-part structure (opportunity framing, design/technical specs, release/post-launch) is a less common but valid framing [source: https://blog.logrocket.com/product-management/what-is-a-product-requirements-document-prd/].

### What the PRD Excludes

Explicitly outside PRD scope (across sources):

- **Technical implementation** — architecture, programming language, API design. That belongs in an SRD/TRD.
- **Market opportunity analysis** — TAM, competitive landscape in depth. That belongs in an MRD.
- **Business case justification** — ROI, org alignment, buy-in rationale. That belongs in a BRD.
- **Pixel-perfect UX design** — wireframes and mockups. Those belong in design artifacts.
- **Delivery backlog** — PRD explains why work matters; backlogs list the work. [source: https://www.productboard.com/blog/product-requirements-document-guide/]
- **Staffing and org detail** — who owns what; that belongs in project charters or RACI.

Productboard states explicitly: "Specs describe outputs, but PRDs define outcomes." The PRD should not be treated as a feature spec sheet or a static file. [source: https://www.productboard.com/blog/product-requirements-document-guide/]

### Lifecycle Position

The canonical sequence across multiple sources:

```
MRD (why build) → BRD (business scope) → PRD (what to build) → SRD/TRD (how to build) → Design artifacts → Test plans
```

[source: https://www.altexsoft.com/blog/product-requirements-document/]

The PRD "occupies the middle stage—following market validation but preceding technical design and implementation planning." [source: https://www.productplan.com/glossary/product-requirements-document]. It is a living document, not a one-time artifact. The Head of Product at YouTube is cited calling it "a living document that should be continuously updated according to the product's lifecycle." [source: https://www.chatprd.ai/learn/what-is-a-prd]

### Contrast with Adjacent Documents

**MRD (Market Requirements Document)** — Precedes the PRD. Answers "why build this?" Addresses market size, growth potential, competitive landscape, product/market fit. Audience: marketing, executives. The PRD is "firmly rooted in use cases and desired functionality" instead. [source: https://www.productplan.com/glossary/product-requirements-document]

**BRD (Business Requirements Document)** — Broader than PRD. Focuses on business goals and organizational objectives; created by business analysts; used to secure stakeholder buy-in. "Think of the BRD as the *why* behind the project, and the PRD as the *how* the team will build the solution." [source: https://www.codelevate.com/blog/brd-vs-prd-the-ultimate-guide-for-product-managers]

**Spec / SRD (Software Requirements Document / Technical Requirements Document)** — Follows the PRD. A technical document written by engineers detailing architecture, APIs, implementation approach. The PRD says what; the SRD says how. [source: https://www.altexsoft.com/blog/product-requirements-document/]

**Design doc** — Parallel or downstream artifact. Focuses on implementation approach, architectural decisions, trade-offs. Typically authored by engineers. Often more volatile than a PRD.

**PRFAQ (Amazon Working Backwards)** — Pre-PRD, customer-centric. Starts from a mock press release and FAQs. "PRFAQs are customer-centric, whereas PRDs are feature-centric." PRFAQs validate market fit and sell the idea internally; PRDs guide development. PRFAQs are iterative narrative; PRDs are structured requirements. [source: https://workingbackwards.com/concepts/working-backwards-pr-faq-process/] [source: https://www.theprfaq.com/]

**Summary table:**

| Doc | Answers | Lifecycle phase | Primary audience |
|---|---|---|---|
| PRFAQ | Is this worth building? | Pre-discovery | Execs, PM |
| MRD | What does the market need? | Discovery | Marketing, execs |
| BRD | What does the business need? | Pre-PRD | Stakeholders |
| PRD | What must we build? | Planning | Eng, design |
| SRD/TRD | How will we build it? | Design/impl | Engineers |
| Design doc | What are the trade-offs? | Design | Engineers |

---

## 2. Human-to-Agent Adaptation

### The Fundamental Shift

Traditional PRDs were written for humans who bring contextual judgment, can ask clarifying questions mid-implementation, and interpret ambiguous requirements reasonably. When the implementer is an LLM agent, that buffer disappears.

"A machine-legible requirement is not just a well-written requirement. It's a requirement that leaves no escape hatches for creative interpretation." Agents silently resolve contradictions and fill unspecified edge cases with patterns from training data. "The result appears reasonable but diverges from actual requirements." [source: https://glenrhodes.com/the-overlooked-skill-in-agentic-development-writing-machine-legible-requirements-and-specs]

Similarly: "In agentic development, the PRD or spec is closer to a runtime artifact that the agent executes against directly, sometimes literally using it as the system prompt or as the grounding document for a planning step, and the quality of that document determines the quality of the output with almost no buffering." [source: https://agentfactory.panaversity.org/docs/General-Agents-Foundations/spec-driven-development]

The ChatPRD guide on AI codegen confirms: "traditional PRDs communicate *what* to humans who infer *how*; AI PRDs must specify both *what* and *how* it should work within clearly stated boundaries." [source: https://www.chatprd.ai/learn/prd-for-ai-codegen]

### What Changes

#### Acceptance Criteria: From Prose to Predicates

Human PRDs tolerate subjective language ("should feel fast," "easy to use"). Agent PRDs require binary, verifiable predicates.

Before (human): "Responsive design"
After (agent): "Loads in <2 seconds on 4G; viewport adapts to 320–1920px width" [source: https://medium.com/@haberlah/how-to-write-prds-for-ai-coding-agents-d60d72efb797]

Before (human): "should not hallucinate"
After (agent): "must not cite a source that was not present in the retrieved context" [source: https://labs.adaline.ai/p/ai-prd-missing-sections]

The ProdMoh framework advocates machine-parsable predicate syntax: `{"type":"predicate","expr":"response.status == 200"}` [source: https://prodmoh.com/blog/ai-prd-structure].

#### Non-Goals: From Optional to Mandatory

"AI cannot infer from omission and every boundary must therefore be stated positively." [source: https://www.chatprd.ai/learn/prd-for-ai-codegen]

Non-goals are the primary scope-creep guard. Agents have no social contract to stay in scope; they optimize for task completion as they interpret it. Scope creep from autonomous agents is described as "real and quiet." [source: https://glenrhodes.com/the-overlooked-skill-in-agentic-development-writing-machine-legible-requirements-and-specs]

#### Phased Structure: From Holistic to Sequential

Traditional PRDs present features holistically. Agent-optimized specs restructure as dependency-ordered, testable phases. Each phase should represent a bounded unit of work (~5-15 minutes of agent work) ending with manually verifiable functionality.

Example transformation: "System must allow audio upload, organization, playback with visualization and playlists" becomes:
1. Database schema and storage
2. Upload and library API
3. Playback engine
4. Visualization
5. Playlist management
6. UI polish

[source: https://medium.com/@haberlah/how-to-write-prds-for-ai-coding-agents-d60d72efb797]

### Sections That Gain Importance

#### Behavioral Constraints / Hard Stops

Agents require explicit enumeration of prohibited behaviors — not soft guidance, but hard constraints. Three-tier boundary model:

- **Always do** — safe actions requiring no approval
- **Ask first** — high-impact changes needing review
- **Never do** — hard stops (secrets, destructive ops, out-of-scope domains)

[source: https://addyosmani.com/blog/good-spec/]

The ainna.ai AI PRD guide formalizes this as a "behavioral contract" specifying: what the system attempts, how well it performs (ranges, not exact outputs), what it must never do (guardrails), how gracefully it fails, and how its behavior changes over time. [source: https://ainna.ai/resources/faq/ai-prd-guide-faq]

Concrete examples: "Must not fabricate citations." "Must decline politely with specific message for out-of-scope inputs." "Must label uncertainty when speaker intent is ambiguous." [source: https://labs.adaline.ai/p/ai-prd-missing-sections]

#### Failure Modes

"AI products can fail silently—producing confident-sounding but wrong outputs that users trust." [source: https://ainna.ai/resources/faq/ai-prd-guide-faq] Traditional software "breaks visibly"; AI fails quietly.

Failure modes must be derived from observed prototype outputs, not imagination. One team discovered the constraint "must not infer resolution from user silence" only after observing real failures. [source: https://labs.adaline.ai/p/ai-prd-missing-sections]

Required failure mode documentation for each mode: detection method, user-facing response, internal alerting, recovery procedure.

For agent-as-implementer (not AI-as-product), failure modes shift to: what happens if the agent misunderstands scope, produces breaking changes to stable code, enters a loop, or exhausts context.

#### DO NOT CHANGE Sections

Explicit preservation guards on stable functionality that must not be modified. Agents lack contextual judgment distinguishing "improvable code" from "must remain stable." [source: https://medium.com/@haberlah/how-to-write-prds-for-ai-coding-agents-d60d72efb797]

#### Concrete Input/Output Examples

"Input/output examples anchor behavior and reduce hallucination." [source: https://prodmoh.com/blog/agentic-prd] One real code snippet beats paragraphs of description. Examples serve as implicit test cases and ground the agent in concrete expectations.

#### Verification / Checkpoint Protocol

Each phase ends with checkpoint criteria enabling rollback to known-good states. Agents cannot self-assess whether they've drifted; checkpoints externalize that judgment. [source: https://medium.com/@haberlah/how-to-write-prds-for-ai-coding-agents-d60d72efb797]

#### Observability Specification

Agent PRDs for AI products must specify what telemetry the agent's actions produce. The n-ix.com framework requires four telemetry layers: behavioral (reasoning steps, tool calls, decision branching), operational (latency, tokens, error rates), decision (output quality, hallucination frequency), and governance (audit trails, data access). [source: https://www.n-ix.com/ai-agent-observability/]

Even for non-AI-product PRDs (i.e., the product is built by an agent), the PRD should specify which agent decisions require logging, which tool calls require human review, and what constitutes a detectable deviation.

#### Evals as Acceptance Criteria (for AI-as-product)

When the product itself involves LLM outputs, traditional acceptance criteria fail. The ainna.ai guide identifies this as "the most significant conceptual shift." Replace "the feature works correctly" with eval frameworks: algorithmic judges (format validation), AI-as-judge (subjective quality), human-aligned evaluation (ground truth). Evals run continuously on production outputs, not just at ship. [source: https://ainna.ai/resources/faq/ai-prd-guide-faq]

#### Glossary / Semantic Metadata

Domain definitions eliminate ambiguous terminology. Agents interpret terms literally; jargon or overloaded terms cause silent misalignment. The prodmoh.com framework lists "semantic metadata & glossary" as one of five structural pillars. [source: https://prodmoh.com/blog/agentic-prd]

### Sections That Diminish or Get Cut

**UX prose and design narrative** — Substantially reduced unless there is a UI. UX flows, personas, and visual descriptions consume tokens without constraining agent behavior. Replace with input/output examples and acceptance criteria.

**Org/staffing detail** — Who owns what, team structure, RACI. Irrelevant to an agent implementer. May be retained for human readers in a header, but should not appear in agent-facing sections.

**Market analysis in body** — MRD-layer content (TAM, competitive landscape) does not inform implementation. Belongs in a separate preamble if at all.

**Soft constraints** — Any language relying on professional judgment ("use good practices," "follow conventions") is useless to an agent. Either make it concrete or cut it.

**Implied scope** — Everything that is implied but not stated is invisible to agents. Implied scope must be stated positively or treated as agent-optional.

### Emerging Conventions

**Spec-Driven Development (SDD)** — A movement positioning the spec as the primary artifact, with code as a generated output. Uses four gated phases: Specify → Plan → Tasks → Implement. The spec is the "source of truth" and the primary grounding document for agent execution. [source: https://agentfactory.panaversity.org/docs/General-Agents-Foundations/spec-driven-development] [source: https://www.augmentcode.com/guides/claude-code-spec-driven-development]

**Anthropic Agent Skills pattern** — SKILL.md files serve as executable, agent-loaded specifications. Skills use progressive disclosure: minimal metadata (~100 tokens) at startup, full instructions loaded on demand. This is the production pattern in the cortex.lan environment. [source: https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills]

**CLAUDE.md / hub-and-spoke structure** — Top-level spec index points to deeper spec documents. Prevents context overload. Structure: `CLAUDE.md` (index + hard constraints) + `docs/specs/00-overview.md`, `01-requirements.md`, etc. [source: https://www.augmentcode.com/guides/claude-code-spec-driven-development]

**MCP-integrated specs** — Emerging convention to link PRDs to live databases and APIs via Model Context Protocol, keeping context grounded. Mentioned by chatprd.ai as a requirement for agentic PRDs. [source: https://www.chatprd.ai/learn/prd-for-ai-codegen]

**Known limitation — spec drift** — Augment Code documents that Claude Code agents "skip instructions" in CLAUDE.md and "rewrite or bypass tests rather than fix underlying code." Spec compliance is not guaranteed by spec presence. This limits the value of a beautifully structured spec alone; verification loops and checkpoint protocols are required. [source: https://www.augmentcode.com/guides/claude-code-spec-driven-development]

**No consensus on schema format** — Some sources advocate JSON schema for acceptance criteria (prodmoh.com); most working implementations use structured Markdown. The snarktank/ralph PRD skill and jamesrochabrun/skills PRD generator both produce Markdown, not JSON. [source: https://github.com/snarktank/ralph/blob/main/skills/prd/SKILL.md] [source: https://github.com/jamesrochabrun/skills/blob/main/skills/prd-generator/SKILL.md] There is no industry-wide standard format as of 2026.

**OpenAI Product Lead template** — The Miqdad Jaffer AI PRD template adds dedicated AI-specific NFRs (accuracy targets, hallucination rates, bias audits) and "continuous PRM mode" treating the PRD as a living document requiring constant assumption testing. Notable absence: no explicit behavioral contract or non-goals list — risk management is folded into a product scope section. [source: https://www.productcompass.pm/p/ai-prd-template] This is a minority approach; most sources treat non-goals and behavioral constraints as mandatory top-level sections.

---

## 3. Recommendations for the `prd-writing` Skill

1. **Produce two logical layers in one document.** A preamble for human readers (problem, users, lifecycle context) followed by an agent-executable body (predicates, examples, constraints, non-goals, checkpoints). The snarktank/ralph skill pattern of nine explicit sections is a sound baseline. The jamesrochabrun pattern of 13 sections adds success metric frameworks (AARRR, HEART) that are useful for AI-as-product but bloat for agent-as-implementer.

2. **Treat non-goals as a mandatory, top-level section, not a footnote.** Every feature boundary not stated is implicitly open to the agent. Non-goals should name adjacent capabilities that were considered and rejected, not just vague scope statements. Pattern: "This PRD does not cover X, Y, Z. If the agent encounters a need for any of these, it must stop and surface the gap."

3. **Require behavioral constraints (hard stops) as a named section.** Distinct from non-goals. Format: three-tier — Always / Ask first / Never. Always-list and Never-list are non-negotiable sections. Ask-first list is recommended. This is absent from most traditional PRD templates and is the single largest gap between human-targeted and agent-targeted PRDs.

4. **Acceptance criteria must be binary and verifiable.** The skill should detect and flag subjective language ("should feel," "easy," "intuitive," "good") and prompt for quantified replacements. Each criterion should have a clear pass/fail test. For AI-as-product PRDs, criteria map to eval frameworks (algorithmic, AI-judge, human).

5. **Include concrete input/output examples for every non-trivial requirement.** One example eliminates more ambiguity than a paragraph of prose. The skill should prompt for at least one example per functional requirement and mark requirements without examples as incomplete.

6. **Add a failure-mode section derived from prototype observation, not speculation.** The Adaline Labs finding — that useful failure modes come from reviewing 20-50 real outputs, not imagination — should be encoded in the skill's interview phase. For agent-as-implementer PRDs, failure modes include: misunderstood scope, breaking changes to stable code, context exhaustion, and silent divergence. For AI-as-product PRDs, add: hallucination, confidence threshold breach, context overflow, adversarial prompt injection.

7. **Add a DO NOT CHANGE section for any PRD that modifies existing systems.** Any requirement that touches existing code must explicitly enumerate stable interfaces, files, or behaviors that must not be altered. This directly prevents the "agents lack contextual judgment" failure mode documented in Haberlah and Augment Code's research.

8. **Distinguish AI-as-product PRDs from agent-as-implementer PRDs.** These are two different use cases with different required sections. AI-as-product (the product uses an LLM) needs: evals framework, model strategy, guardrails specification, data requirements, responsible AI, monitoring/adaptation plan, cost/latency as product decisions. Agent-as-implementer (an LLM builds the product) needs: phased sequential structure, DO NOT CHANGE guards, checkpoint protocol, behavioral hard stops, machine-verifiable ACs. The skill should ask which type applies and adjust template accordingly. Both can coexist in one PRD if the agent is building an AI product.

---

## 4. Sources

- https://www.atlassian.com/agile/product-management/requirements
- https://www.productplan.com/glossary/product-requirements-document
- https://www.productboard.com/blog/product-requirements-document-guide/
- https://blog.logrocket.com/product-management/what-is-a-product-requirements-document-prd/
- https://www.altexsoft.com/blog/product-requirements-document/
- https://www.codelevate.com/blog/brd-vs-prd-the-ultimate-guide-for-product-managers
- https://www.findernest.com/en/blog/understanding-prd-brd-mrd-and-srd-a-quick-guide
- https://workingbackwards.com/concepts/working-backwards-pr-faq-process/
- https://www.theprfaq.com/
- https://medium.com/@haberlah/how-to-write-prds-for-ai-coding-agents-d60d72efb797
- https://labs.adaline.ai/p/ai-prd-missing-sections
- https://prodmoh.com/blog/agentic-prd
- https://prodmoh.com/blog/ai-prd-structure
- https://www.chatprd.ai/learn/prd-for-ai-codegen
- https://ainna.ai/resources/faq/ai-prd-guide-faq
- https://www.productcompass.pm/p/ai-prd-template
- https://addyosmani.com/blog/good-spec/
- https://glenrhodes.com/the-overlooked-skill-in-agentic-development-writing-machine-legible-requirements-and-specs
- https://agentfactory.panaversity.org/docs/General-Agents-Foundations/spec-driven-development
- https://www.augmentcode.com/guides/claude-code-spec-driven-development
- https://www.anthropic.com/research/building-effective-agents
- https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills
- https://www.n-ix.com/ai-agent-observability/
- https://github.com/jamesrochabrun/skills/blob/main/skills/prd-generator/SKILL.md
- https://github.com/snarktank/ralph/blob/main/skills/prd/SKILL.md
- https://www.reforge.com/blog/product-requirement-document-prd-templates
