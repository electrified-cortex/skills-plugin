---
name: skill-eval
description: Evaluate a target skill across multiple trials and model classes to produce a recommendation on which model tier executes it best. Triggers — evaluate skill, skill evaluation, benchmark skill, skill trial, measure skill quality, which model for this skill.
---

Input:
- `target_skill` (required) — path to the target skill folder (e.g. `../compression/`).
- `sample_inputs` (required) — path to a folder of sample input files OR a JSON array of input objects.
- `trials` (required, integer 1–10) — number of trials per (input × model class) cell.
- `model_classes` (optional, default `haiku-class,sonnet-class,opus-class`) — which model classes to test.
- `scoring` (required) — path to a scoring module OR an inline scoring directive. No default — eval refuses to run without one.

Caller obligations:
- Supply `scoring`. Eval does not infer success from absence of error.
- Pre-create sample inputs. Eval does not synthesize them.
- Set `trials` deliberately (more = more cost; fewer = less signal). Max 10.

Procedure:
1. Load target skill SKILL.md to confirm it is dispatchable.
2. Load sample inputs and scoring.
3. For each model class: for each sample input: run `trials` trials dispatching the target skill at that model class against the input. Capture output, latency, error.
4. Apply caller-supplied scoring to each trial → per-trial score (PASS / FAIL / PARTIAL).
5. Aggregate per (model class × input): pass rate, mean latency, error rate.
6. Aggregate per model class overall.
7. Generate recommendation: best model class by pass rate + cost/latency notes.
8. Write report via `audit-reporting` (target-kind = `eval`).

Output — report body:
- Recommendation block (one line: best model class + caveats).
- Per-model-class summary table (pass rate, mean latency, error rate).
- Per-input results table.
- Failure inventory (every FAIL with input ID, model class, trial number, error).

Constraints:
- Do NOT run without `scoring` — no fallback.
- Do NOT exceed `trials` = 10.
- Do NOT modify the target skill. Eval is read-only against the target.
- Do NOT write sample inputs into the target skill folder.
- Do NOT re-audit unchanged files. See `../iteration-safety/SKILL.md`.
- Model classes MUST be resolved via `../dispatch/SKILL.md` class mapping — no bare model IDs.
- If spec contradicts eval results, empirical result takes precedence.
