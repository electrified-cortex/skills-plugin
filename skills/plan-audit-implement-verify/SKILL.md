---
name: plan-audit-implement-verify
description: Meta-skill for disciplined execution - plan, audit, implement, verify. Triggers - plan audit implement verify, PAIV, plan a change, audit my plan, implement this plan, verify this change, before I delete, no cowboy.
---

Given your task, instruction, or request:

## 1. Plan

Write a plan, in order, with enough detail that another agent could execute it.

## 2. Audit

Dispatch a scope-isolated sub-agent (background preferred) via the `dispatch` skill. Load `audit.txt` as its instructions; pass the plan as input. The sub-agent returns PASS / NEEDS-REVISION / FAIL. Address findings and re-dispatch if NEEDS-REVISION; cap revisions around 3 and escalate if it won't converge.

## 3. Implement

Execute the plan. Inline (host) for small changes; dispatch a sub-agent for larger ones (the plan is the brief).

## 4. Verify

Dispatch a scope-isolated sub-agent via the `dispatch` skill. Load `verify.txt` as its instructions; pass the plan plus the implementation (typically a staged diff) as input. The sub-agent returns PASS / NEEDS-REVISION / FAIL. On NEEDS-REVISION or FAIL, return to Implement (mechanical fix) or Plan (planning defect).
