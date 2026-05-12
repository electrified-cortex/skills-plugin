---
name: messaging
description: File-based agent-to-agent messaging via shared inbox. Triggers - registering an inbox, posting a message to another agent, reading inbox messages, monitoring for incoming messages, draining an inbox, checking inbox status, setting up inter-agent communication, leaving a message for another agent.
---

Agents communicate via inbox msg files. Four tools handle all mechanics; agent supplies intent only.

`init` — register inbox on startup; claims name atomically
`post` — post msg to another agent's inbox
`drain` — collect pending msgs from own inbox
`status` — Monitor callback; counts unclaimed msgs, reports pending count

Inbox = dir in shared workspace. Any agent with filesystem access can post to any inbox. No security model; isolation conventional.

Concepts:
`Inbox` — `.inbox/<agent-name>/` relative to workspace root. Each agent owns one.
`Signal file` — `.inbox/<agent-name>/.signal`. `post` writes after each successful msg write. Agents watch for changes.
`Archive` — `.inbox/<agent-name>/archive/`. Drained msgs moved here after reading. No protocol role; may be purged freely.
`Claim` — exclusive reservation `drain` takes on msg file; prevents concurrent drain reading same msg.
`Name claim` — atomic dir creation `init` performs. Only one caller can create `.inbox/<name>/`; others get "already registered." Establishes agent identity.
`Status` — lightweight read-only probe. Wire to Monitor as signal-change callback; counts unclaimed msgs, outputs pending count. Doesn't claim or modify files.
`Msg file` — `.json` file in inbox. Filename: `YYYYMMDDTHHmmssZ-<nonce>.json`. Example: `20260508T143022Z-a3f91b.json`.

Each msg file: JSON object with fields `from`, `sent`, `body`, and optional `subject`:

```json
{
  "from": "curator",
  "sent": "2026-05-08T14:30:22Z",
  "subject": "Task complete — review requested",
  "body": "The batch run finished. Results are in .work/batch-42/. Ready for your review."
}
```

Registering:
Call `init` once on first startup. Creates inbox, archive, signal file; claims name atomically. If name taken, exits non-zero.

```text
init --name <your-name>
```

On restart, `--force` reclaims without failing:

```text
init --name <your-name> --force
```

`--force` never modifies existing msgs.

Posting:
Invoke `post`; generates filename, timestamp, nonce; writes atomically. Don't write inbox files directly.

```text
post --from <your-name> --to <recipient> --subject "<subject>" --body "<body>"
```

All 4 flags required. `post` exits 0 on success, non-zero on failure (error on `stderr`). Check exit code.

Example:

```text
post --from curator --to overseer --subject "Batch complete" --body "Results in .work/batch-42/."
```

Don't post to own inbox.

Monitoring:
Watch signal file for changes. On change, drain inbox.

Signal file: `.inbox/<own-name>/.signal`

Option A — Wire status to Monitor:
Configure Monitor to call `status` on signal change; counts unclaimed msgs, outputs single line.

```text
status --inbox <your-name>
# outputs: [2026-05-08T14:30:22Z]: 5 messages waiting
```

Read count. Drain if msgs waiting.

Option B — implement loop yourself:

```text
on startup:
    drain and process until empty

watch .inbox/<own-name>/.signal for changes:
    on change:
        loop:
            messages = drain --inbox <own-name>
            if messages is empty: break
            for each message: process it
        resume watching
```

Drain-to-quiescence loop (inner `loop`) required; ensures nothing stranded.

On Startup:

1. `init --name <own-name>` (or `--force` on restart).
2. Drain once — msgs posted while offline waiting.
3. Enter monitoring loop.

Draining:

```text
drain --inbox <your-name>
```

`drain` returns JSON array of pending msgs oldest-first. Per msg: claims file, reads content, moves to `archive/`. On claim failure, skips silently.

`drain` ALWAYS full sweep — one invocation collects all pending msgs, not just one. Exits 0 even if files skipped. Empty inbox returns `[]`.

Don't drain another agent's inbox. Archives files even if unparsable; failure on `stderr`.

Processing:
For each msg object in JSON array from `drain`:

1. Read fields: `from`, `sent`, `body`. Check for optional `subject`.
2. Process body.
3. If field missing or body unhandled, log failure and continue.

Single bad msg MUST NOT halt inbox processing.

Ordering:
Oldest-first. Filename sort guarantees order — filenames begin with UTC timestamp. Per-sender order preserved; cross-sender interleaves by timestamp.

Constraints:
No delivery guarantee — msgs accumulate if recipient offline.
No security model — any process with filesystem access can read/post to any inbox.
Single reader per inbox — concurrent drains unsupported.
No msg expiry or TTL in v1.

Don'ts:
DON'T skip `init` on startup — register before draining or watching.
DON'T call `init` without `--force` on restart.
DON'T write inbox files directly — use `post`.
DON'T drain another agent's inbox.
DON'T delete msg files — archive is only terminal state.
DON'T post to own inbox.
DON'T halt on single failing msg — log and continue.
DON'T assume inbox is private.

Tools (co-located):
`init.sh` / `init.ps1` — register inbox
`post.sh` / `post.ps1` — post message
`drain.sh` / `drain.ps1` — drain inbox
`status.sh` / `status.ps1` — count pending messages

Related:
`markdown-hygiene` — sealing step; run on uncompressed sources after audit PASS
`skill-auditing` — audits this skill
`compression` — compresses `uncompressed.md` to `SKILL.md`
