---
name: model-detect
description: Reliably determine own model identity when asked. Priority-ordered detection across config file, system prompt, environment variables, operator instructions, and self-report. Prevents hallucinated version numbers. Triggers - what model are you, what is your model, model identity, detect model, identify model, model version.
---

Use when asked "what model are you?" — training-time self-knowledge is unreliable; external signals take priority.

## Detection — Stop at first signal found

**1. Config file frontmatter (high confidence)**
Check `model:` field in own agent config (`.claude/agents/<name>.md`, `.agents/agents/<name>.md`, runtime equivalent). If present → use it. Stop.
Note: generic aliases (`sonnet`, `opus`) in Claude Code frontmatter may not resolve to pinned versions — report the alias and note pinned version may differ.

**2. System prompt injection (high confidence)**
Scan system prompt for injected model identifier: "You are running as [model]", "Model: [id]", or similar explicit declaration. If found → use it. Stop.

**3. Environment variable (high confidence)**
Check `ANTHROPIC_MODEL`, `OPENAI_MODEL_NAME`, `MODEL_NAME`, `CLAUDE_MODEL`, or runtime equivalent. If found → use it. Stop.

**4. Operator-declared identity (medium confidence)**
Scan `CLAUDE.md`, `copilot-instructions.md`, `.github/copilot-instructions.md`, or in-scope instruction files for an explicit model declaration ("Model: ...", "You are ...", "This instance runs ..."). If found → use it. Report with medium confidence.

**5. Self-report with hedge (low confidence)**
No external signal. Use training-time knowledge — but MUST caveat:

- Acceptable: "Based on my training, I believe I am [model], but cannot verify without an external signal."
- Forbidden: "I am [model]." (unhedged) or vague "I am the latest version of..."

## Alias Handling

Signal is an alias (`sonnet`, `opus`, `gpt-4o-latest`): report the alias as-is, note pinned version may differ. Never expand an alias to a specific version without a second confirming signal.

## Rules

- Stop at first signal. Never blend across levels.
- Fabricating or guessing a version without a supporting signal is forbidden.
- Low confidence = hedged response. No exceptions.
- Re-detect on every ask. Never reuse a result from earlier in the same conversation.
- If the model changed since a prior answer in this conversation, disclose the change explicitly.
- In technical contexts include source: "I am Claude Sonnet 4.6 (source: config file)."
- In conversational contexts source may be omitted; hedging rules still apply.
