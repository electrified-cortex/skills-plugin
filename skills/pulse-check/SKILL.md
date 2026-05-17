---
name: pulse-check
description: Periodic self-check watchdog for assistant-class pods (Curator, BT, Overseer, assistant-pod template and derivatives). Verifies Telegram session, activity-file monitor, inbox monitor, and message queue every 60 minutes. Surfaces only on divergence; silent on all-green. Triggers — pulse check, session liveness, silent failure watchdog, monitor re-arm, reconnect session, activity monitor gap, inbox monitor gap.
---

Scope: Curator, BT, Overseer, assistant-pod template and derivatives (e.g. Zhuli). NOT Foreman or Worker pods — they have no Telegram and no activity-file monitor.
Vocabulary: "pulse" in all agent speech and user-facing output. NEVER "heartbeat."

## Load Procedure

Run on every SessionStart (cold boot) AND every SessionStart:compact wake. Both paths re-register.

1. `CronList` → find any job whose prompt contains `pulse-check`. `CronDelete` each match. (Prevents duplicates after compaction — cron does not survive compaction.)
2. `CronCreate(cron: "7 * * * *", prompt: "Pulse-check cron fired — invoke the pulse-check skill.", recurring: true)` — 60-min schedule, session-scoped.
3. Fire one pulse immediately (compact wake = highest-risk silent-failure moment; unconditional per R1a).

## Pulse Fire Procedure

### Guard 1 — Self-skip

Check recency of last user message in conversation context. If < 10 minutes ago: exit silently. No log, no output.

### Guard 2 — Idempotency lock

```bash
cat .pulse-check.lock 2>/dev/null
```

If lock exists and its timestamp is < 60 seconds ago: another fire is in progress — skip silently.
Otherwise: write current UTC epoch seconds to `.pulse-check.lock` and proceed.
Remove lock at end of procedure (success or failure path).

### Checks

Run checks 1–3 sequentially. For each: attempt recovery on failure. Retry budget: 3 attempts per check per fire. After 3 failures on one check: surface escalation message, stop retrying that check. Budget resets next fire.
Check 4 (queue drain) is always pass — no recovery needed.

**Check 1 — Telegram session live**
`action(type: 'reminder/list', token)` → error or exception = session dead.
Recovery: `action(type: 'session/reconnect')`.
Surface on recovery success: "reconnected Telegram session."
Surface on budget exhausted: "cannot self-recover Telegram session after 3 attempts — escalating."

**Check 2 — Activity-file monitor alive**
`action(type: 'activity/file/get')` → returns current activity file path.
`TaskList` → find a live (non-completed, non-stopped) task whose command or description references that path.
If none found: re-arm via `Monitor` on that path (persistent).
Surface on recovery success: "re-armed activity monitor."
Surface on budget exhausted: "cannot self-recover activity monitor after 3 attempts — escalating."

**Check 3 — Inbox monitor alive**
`TaskList` → find a live task whose command contains `inbox/monitor.sh`.
If none found: re-arm via `Monitor` running `bash inbox/monitor.sh --prefix Inbox` (persistent).
Surface on recovery success: "re-armed inbox monitor."
Surface on budget exhausted: "cannot self-recover inbox monitor after 3 attempts — escalating."

**Check 4 — Telegram queue drain**
`dequeue(max_wait: 0)` → collect any pending messages. Process each normally. Always passes; silent.

### All-green path

All checks pass: append `[ISO8601Z] pulse: all green` to `.pulse-check.log`. Emit zero user-facing output.

## Surface Message Format

One line per finding. Tone: light, not alarming — a routine notice, not an alert.

> Pulse check — [finding]: [action taken].

Examples:
- "Pulse check — activity monitor was gone: re-armed."
- "Pulse check — Telegram session was dead: reconnected."
- "Pulse check — inbox monitor was missing: re-armed."
- "Pulse check — cannot self-recover inbox monitor after 3 attempts: escalating."

Multiple findings in one fire: one line per finding, sequential.
