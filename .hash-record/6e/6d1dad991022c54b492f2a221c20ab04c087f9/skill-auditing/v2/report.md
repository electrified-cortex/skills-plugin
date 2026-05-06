---
file_paths:
  - publish/SKILL.md
  - publish/spec.md
operation_kind: skill-auditing/v2
model: sonnet-class
result: fail
---

# Result

FAIL

## Skill Audit: publish

**Verdict:** FAIL
**Type:** inline
**Path:** publish/

### Step 1 - Compiled Artifacts

| Check | Result | Notes |
| --- | --- | --- |
| Classification | PASS | Inline skill; all procedure steps self-contained in SKILL.md. No instructions.txt present. Agent can execute from inputs alone. |
| Inline/dispatch consistency | PASS | No dispatch instruction files present; SKILL.md contains full procedure. Consistent. |
| Structure | PASS | Frontmatter, preflight, numbered procedure, bailout table, dependencies, anti-patterns sections present. |
| Input/output double-spec (A-IS-1) | PASS | N/A; no sub-skills invoked that dictate output path. |
| Sub-skill input isolation (A-IS-2) | N/A | No sub-skill dispatch. |
| Frontmatter | PASS | name: publish, description present. Extra fields (version, inputs) are non-standard but not prohibited. |
| Name matches folder (A-FM-1) | PASS | name: publish matches folder name publish/. |
| H1 per artifact (A-FM-3) | PASS | SKILL.md contains no real H1 outside frontmatter. |
| No duplication | PASS | No evidence of a pre-existing equivalent skill. |
| Orphan files (A-FS-1) | PASS | Only SKILL.md and spec.md present; both are well-known role files. |
| Missing referenced files (A-FS-2) | PASS | Build scripts referenced as external dependencies, not co-located skill files. |

### Step 2 - Parity

| Pair | Result | Notes |
| --- | --- | --- |
| SKILL.md vs uncompressed.md | N/A | uncompressed.md absent. Advisory: SKILL.md is 69 lines, near 60-line threshold. |
| instructions.txt vs instructions.uncompressed.md | N/A | No instructions.txt (inline skill). |

### Step 3 - Spec Alignment

| Check | Result | Notes |
| --- | --- | --- |
| Spec exists | PASS | spec.md present co-located with publish/. |
| Required sections | FAIL | spec.md is missing a Purpose heading. Opens with H1 title and intro paragraph but no labeled Purpose section. Required: Purpose, Scope, Definitions, Requirements, Constraints. |
| Normative language | PASS | R1-R12 use MUST, MUST NOT, required. Constraints use MUST NOT. Enforceable throughout. |
| Internal consistency | PASS | No contradictions between spec sections. No duplicate rules. |
| Spec completeness | PASS | All terms defined. Behavior explicitly stated. Edge cases addressed. |
| Coverage | FAIL | Two gaps: (1) Spec Outputs includes push result in status report; SKILL.md step 9 omits it. (2) Three spec Constraints absent from SKILL.md: MUST NOT decide whether to release, MUST NOT bump per-skill versions, MUST NOT amend or rewrite history. |
| No contradictions | FAIL | SKILL.md hardcodes main in preflight and push. Spec defines release branch as configurable via build/config.yaml release_branch key (default main). R2 says not the configured release branch. SKILL.md ignores configurability. |
| No unauthorized additions | FAIL | SKILL.md step 6 includes Operator may amend - absent from spec. Spec Constraint: MUST NOT amend or rewrite history of prior commits. |
| Conciseness | PASS | Procedure is dense and operational. Sections are brief. |
| Completeness | PASS | Runtime instructions present for happy path and all error paths in R1-R12. |
| Breadcrumbs | FAIL | SKILL.md has no Related section. Spec has a Related section referencing build scripts, plugin.json, memory files. |
| Cost analysis | N/A | Inline skill. |
| No dispatch refs | N/A | Inline skill; no instructions.txt. |
| No spec breadcrumbs | PASS | SKILL.md contains no references to spec.md. |
| Eval log (informational) | ABSENT | No eval.txt present. Does not affect verdict. |
| Description not restated (A-FM-2) | FAIL | Body opener paraphrases frontmatter description (not verbatim). LOW. |
| No exposition in runtime (A-FM-5) | FAIL | Anti-patterns section contains rationale suffixes after em-dashes. HIGH. |
| No non-helpful tags (A-FM-6) | PASS | No bare type labels or non-operational descriptor lines found. |
| No empty sections (A-FM-7) | PASS | All sections contain body content. |
| Iteration-safety placement (A-FM-8) | N/A | Inline skill; no instructions.txt. |
| Iteration-safety pointer form (A-FM-9a) | N/A | No iteration-safety reference present. |
| No verbatim Rule A/B (A-FM-9b) | N/A | No iteration-safety content found. |
| Cross-reference anti-pattern (A-XR-1) | PASS | No pointers to other skills uncompressed.md or spec.md found. |
| Launch-script form (A-FM-10) | N/A | No uncompressed.md present. |
| Return shape declared (DS-1) | N/A | Inline skill. |
| Host card minimalism (DS-2) | N/A | Inline skill. |
| Description trigger phrases (DS-3) | N/A | Inline skill. |
| Inline dispatch guard (DS-4) | N/A | Inline skill. |
| No substrate duplication (DS-5) | N/A | Inline skill. |
| No overbuilt sub-skill dispatch (DS-6) | N/A | Inline skill. |

### Per-file Basic Checks

| File | Check | Result | Notes |
| --- | --- | --- | --- |
| SKILL.md | Not empty | PASS | 69 lines, substantial content. |
| SKILL.md | Frontmatter | PASS | YAML frontmatter present at line 1. |
| SKILL.md | No abs-path leaks | PASS | No Windows-style or Unix root-anchored paths in body. |
| spec.md | Not empty | PASS | 100 lines, substantial content. |
| spec.md | Frontmatter | N/A | spec.md does not require frontmatter. |
| spec.md | No abs-path leaks | PASS | No absolute paths found. |

### Issues

**FAIL findings:**

1. [Step 3 / Required sections] spec.md missing Purpose section. Fix: add ## Purpose as first H2 after the H1, move intro paragraph under it.

2. [Step 3 / No contradictions] SKILL.md hardcodes main instead of configured release branch. Preflight and push steps use main literally; spec defines release_branch as configurable. Fix: replace main literals with the configured release branch read from build/config.yaml, defaulting to main.

3. [Step 3 / Coverage] SKILL.md step 9 return omits push result. Spec Outputs includes push result in status report. Fix: append push result to step 9 return list.

4. [Step 3 / Coverage] Three spec Constraints not in SKILL.md: MUST NOT decide whether to release; MUST NOT bump per-skill versions inside plugin.json; MUST NOT amend or rewrite history. Fix: add Constraints section covering all six spec constraints.

5. [Step 3 / No unauthorized additions] Operator may amend in step 6 not sanctioned by spec. Fix: remove it.

**HIGH findings:**

6. [Step 3 / A-FM-5] Anti-patterns rationale suffixes. Each bullet appends a why-explanation after the em-dash. Rationale belongs in spec.md. Fix: strip rationale suffixes; leave only the prohibited action.

**LOW findings:**

7. [Step 3 / A-FM-2] Body opener paraphrases frontmatter description. Fix: replace with a context-specific summary that adds information not already in description.

8. [Step 3 / Breadcrumbs] No Related section in SKILL.md. Fix: add brief Related section at end pointing to build/build.ps1, build/deny-list.ps1, plugin.json.

### Recommendation

Fix the five FAIL-level issues (missing Purpose section in spec, hardcoded release branch, missing push result, uncovered Constraints, unauthorized Operator may amend), then address the HIGH exposition issue in Anti-patterns before marking ready for merge.