# code-review eval log

## Round 1 — 2026-04-26 PM

**Target:** `Telegram MCP/src/button-validation.ts` (23 lines, single-file, two functions).
**Approach:** Manual dogfood — Curator dispatched 2 personalities (Code Reviewer + Devil's Advocate, both sonnet-class) in parallel against the file. Curator played arbitrator manually.
**Output:** `Telegram MCP/.code-reviews/files/bba695-L1.md` — 9 consolidated findings (1 blocking, 3 issues, 3 questions, 2 nits, 1 non-blocking).

### What worked

- **Two-personality minimum is enough for trivial files.** 5 + 5 raw findings collapsed to 9 unique after dedup. No need to fire the full 9-personality menu on a 23-line file.
- **Convergence elevates severity.** Both reviewers flagged the empty-array vacuous-pass bug — Code Reviewer at `issue`, DA at `blocking`. Arbitrator picked `blocking`. Single finding stands stronger when reached from two angles.
- **DA value-add was real and non-trivial.** DA caught: Regional Indicators / keycap / ZWJ Unicode gaps in the regex, AND the `\p{Extended_Pictographic}` false-positive (matches `€`, `©`, `™`). Code Reviewer (orthodox) missed both. These are genuine bugs, not philosophical takes.
- **Code Reviewer caught what DA missed.** Whitespace-only label edge case. Confirms the minimum should be BOTH personalities, not just DA solo.
- **`.code-reviews/files/<hash>-L<level>.md` format held up.** Conventional-comments structure (type/file/title/body/evidence/status) reads cleanly. Pre-existing reviews in the TMCP `.code-reviews/` folder used the same format and survived compaction.

### Skill-design takeaways (to encode in spec)

1. **Arbitrator rule: severity-elevation on convergence.** When N≥2 reviewers raise the same finding at different severities, arbitrator picks the highest. Encode in the `swarm` skill's `spec.md` arbitrator section.
2. **Code-review minimum-set rule:** for trivial files (single-file, ≤50 lines, no side-effects, no security path) → `Code Reviewer + Devil's Advocate` is the floor. No need to escalate. Encode in `code-review/spec.md` diff-size-aware-scoping section.
3. **DA is mandatory on substantive content.** This eval validated DA's cross-perspective role — Unicode-class trap, vacuous-truth elevation. Don't make DA optional except for pure documentation/whitespace diffs.
4. **Arbitrator output > raw personality outputs.** Without consolidation, caller sees 10 findings (5+5 with overlap); with arbitrator, 9 unique in severity order. Codify the arbitrator pass as REQUIRED, not optional.

### What didn't surface yet (need more rounds)

- Cache hit rate — only first pass, no re-run yet to verify hash-cache reuse.
- Folder-level integration review — single-file pass only.
- L1→L2 promotion — file didn't surface enough heat to need L2.
- Copilot-CLI cross-vendor DA — wasn't dispatched (operator preference said GPT-codex preferred for DA conceptual passes; not wired yet).

### Next round plan

- Pick a 100-200 line file with side-effects or security touch. Test if larger surface needs more personalities.
- Re-run on same file (button-validation.ts) to verify cache-hit (no re-dispatch, instant return).
- Test with copilot-cli backend wired as DA to confirm cross-vendor diversity benefit.

### Status

Round 1 complete. Findings staged to TMCP `.code-reviews/files/bba695-L1.md`. No content fixes applied yet — operator decides which findings get fixed vs WONT_FIX.

## Round 2a — 2026-04-26 PM (cache-hit verification)

**Target:** Re-dispatch code-review on `button-validation.ts` (already reviewed, hash bba695).
**Approach:** Dispatched Sonnet agent against `code-review/instructions.txt` with the same single-file change_set.
**Output:** Cache hit confirmed — agent verified existence of `bba695-L1.md`, hash match, and skipped swarm dispatch entirely. No new tokens spent on the personality dispatch path. Aggregated output reused cached findings.

### What worked

- Cache lookup at Step 2 fires correctly on full SHA-256 match.
- Aggregated output preserves `cache_hit: true` flag per file.
- No corruption of the existing review file; reuse is read-only.

### Skill-design takeaway

- The cache hit path was previously theoretical; this is the first end-to-end empirical confirmation.
- Decision: add `force_review` flag for callers who want to bypass the cache (eval/QA/regression). Implemented this round across spec.md, uncompressed.md, SKILL.md, instructions.txt, instructions.uncompressed.md.

## Round 2b — 2026-04-26 PM (2-file mixed-cache eval)

**Target:** 2-file change set: `button-validation.ts` (hash bba695, cache hit expected) + `two-lane-queue.ts` (hash 930683, cache miss expected).
**Approach:** Dispatched Sonnet agent against `code-review/instructions.txt`.
**Output:** Mixed cache state handled correctly. Cache hit on file 1 (no swarm dispatch). Cache miss on file 2 → swarm dispatched with trivial-file minimum personality cap (Code Reviewer + Devil's Advocate + TypeScript-reviewer extension preset). New review filed at `.code-reviews/files/930683-L1.md`. Log appended.

### Findings on two-lane-queue.ts (1 nit)

- nit (lines 6-7): re-exports lack `@deprecated` JSDoc. TypeScript 4.0+ propagates `@deprecated` from re-export declarations to consuming sites; without it, IDEs give no migration signal. Real, actionable finding on a 7-line file.

### What worked

- Mixed-cache state (one hit, one miss) executed cleanly.
- Trivial-file minimum cap correctly applied per spec (single file, ≤50 lines, no side-effects, no security).
- Real swarm execution surfaced a substantive finding even on a tiny re-export shim — confirms minimum-set is useful, not just bureaucratic.
- Aggregated output combines cached + fresh findings into one return payload.

### Environmental gaps surfaced (not skill defects, eval-setup issues)

- **Bash hash computation blocked**: Dispatch agents lack `sha256sum`/`node -e` permissions, so they can't compute SHA-256 themselves. Worked around by Curator computing the hash post-hoc and renaming the placeholder review file. Worth filing as a permission-list adjustment for dispatch agents running code-review.
- **swarm/reviewers/ registry absent**: swarm spec normatively references `reviewers/index.md` and `reviewers/<name>.md` body files, but the directory does not exist on disk. Agent had to improvise the swarm dispatch (inline synthesis with class-named personalities). Worth filing as a swarm registry-bootstrap task — author the actual reviewer body files for the built-in personalities so swarm runs with real prompts, not name-only stubs.

### Skill-design takeaways

1. The `force_review` flag landed this round closes the eval-loop gap — without it, the cache hit path is unrunnable for QA after first pass.
2. Trivial-file cap proved its worth twice: button-validation.ts (Round 1, 23 lines) and two-lane-queue.ts (7 lines). The cap is the right floor for sub-50-line files.
3. The audit-reporting citation-verification safeguard added this round addresses the Round 1 audit hallucination on phantom line numbers — generic constraint, not curve-fit.

### Next round

- Round 3: graduate to a folder. Pick a small TMCP folder (e.g., `src/tools/` subset, ≤5 files) and run code-review with full set. Test folder-level integration review pattern at `.code-reviews/folders/<hash>.md`.
- Address the swarm reviewers/ registry gap before going broader — meaningful folder-level tests need real personality bodies.

### Status

Round 2 complete. Both rounds documented. Force flag, citation-verification safeguard, and Round 2 review artifacts all staged.

---

## Round 3 — Effectiveness evaluation (2026-05-02, Worker 1)

**Target:** commit `c68c8045` in Telegram MCP repo — `refactor: remove async from handleAnimationStatus function and adjust test tick handling`
**Files:** `src/tools/animation/status.ts`, `src/tools/send.test.ts`
**Focus:** `correctness,async-safety`

### Dispatch invocation

Smoke pass (Haiku): `instructions.txt`; `change_set=<diff> tier=smoke focus=correctness,async-safety`
Substantive pass (Sonnet): `instructions.txt`; `change_set=<diff> tier=substantive prior_findings=<smoke findings JSON> focus=correctness,async-safety`

### Raw output (aggregated)

**Smoke findings:**
- `minor` — `src/tools/send.test.ts:521`: `vi.runAllTicks()` is not async; removing `await` is technically correct but intent not documented. Recommend inline comment.
- `nit` — `src/tools/animation/status.ts:6`: `async` removal is correct; no issues.

**Substantive findings:**
- `nit` — `src/tools/send.test.ts:521`: Missing comment explaining why `await` was removed; functionally correct. Recommend: `// vi.runAllTicks() is sync; subsequent Promise.resolve() flushes cover microtask propagation`

**Prior-findings disposition:**
- `send.test.ts:521` (smoke: minor) → CONTRADICT → downgraded to `nit`. Removal is unambiguously correct (`vi.runAllTicks()` is synchronous, returns `void`; old `await` was a no-op).
- `status.ts:6` (smoke: nit) → AGREE → `nit` confirmed. Full call-chain check: invocation wrapped in `try/catch` around `Promise.resolve(handler(...))`, so sync exceptions are still caught.

**Aggregated result:**
```json
{"sign_off_pass_index": 1, "verdict": "clean", "severity_aggregate": {"blocker": 0, "major": 0, "minor": 0, "nit": 1}}
```

### Judgment

**Did it find real issues?** The commit is a clean, low-risk refactor. The skill correctly produced no blockers or majors. The one nit (missing comment on `await` removal) is a legitimate maintainability observation, not boilerplate. No false positives.

**Did it miss anything?** The key risk — whether removing `async` breaks exception routing in the `Promise.resolve(handler(...))` call site — was explicitly investigated and resolved. The pre-existing lack of direct unit test for `handleAnimationStatus` was noted (correctly identified as pre-existing, not introduced by this commit).

**Output structure:** Full spec compliance. Both passes produced correct JSON schema (`tier`, `pass_index`, `verdict`, `findings[]` with correct severity vocabulary). Substantive pass included `prior_findings_disposition` with `decision`, `new_severity`, and `commentary`. Smoke correctly omitted it.

**Verdict: HIGH** — accurate calibration, no false positives, correct prior-findings re-examination, full spec-compliant structure.
