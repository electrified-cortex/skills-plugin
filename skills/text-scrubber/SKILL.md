---
name: text-scrubber
description: Detect and fix mojibake and non-ASCII punctuation (arrows, dashes, curly quotes, ellipsis, bullets) in a text file. Triggers - mojibake, garbled quotes, curly quotes, smart quotes, non-ASCII characters, scrub text, fix encoding, chat-unsafe characters.
---

Invoke directly via Bash or PowerShell — no agent dispatch.

```bash
bash scrub.sh <file_path|-> [--fix] [--stdout-only] [--ignore <CATEGORY>]... [--help]
pwsh scrub.ps1 <file_path|-> [--fix] [--stdout-only] [--ignore <CATEGORY>]... [--help]
```

Pass `--help` / `-h` to print usage.

**Arguments**:

- `file_path` — absolute path to the file to scan, or `-` for stdin.
- `--fix` — apply replacements in place (default is detect-only).
- `--stdout-only` — emit the fixed content to stdout without touching
  the source. Mutually exclusive with `--fix`. Works with stdin.
- `--ignore <CATEGORY>` — skip a category; repeatable, or comma-separated
  in one occurrence. `CATEGORY` is one of: `mojibake`, `arrows`,
  `dashes`, `quotes`, `ellipsis`, `bullets`.

**Output** (stdout):

| Result | Line | Exit |
| --- | --- | --- |
| Nothing to scrub | `CLEAN` | 0 |
| Findings (detect mode) | `FINDINGS: <count>` then one `<line>: <category>: '<original>' -> '<replacement>'` per finding | 0 |
| `--fix` applied | `FIXED: <count> replacements applied to <file_path>` | 0 |
| `--stdout-only` | the transformed content, verbatim, no wrapper | 0 |
| Error | `ERROR: <reason>` | 1 |

Auto-fixes only high-confidence patterns (curly quotes/dashes/ellipsis/
bullets and 7 specific mojibake byte-sequences). One low-confidence
mojibake pattern (stray `Â` before a space) is always reported, never
auto-fixed — see `scrub.spec.md` for the full replacement table,
rationale, and a manual fallback procedure for applying every rule by
hand when neither script can be run.

**Scripts** (relative to this folder):

- `scrub.sh` — Bash implementation.
- `scrub.ps1` — PowerShell 7+ implementation. Byte-identical stdout to
  `scrub.sh` for the same input.

Not wired into `markdown-hygiene` or any pre-commit hook — see
`scrub.spec.md`'s "Out of scope" section for that follow-up.

Related: `tool-writing`, `tool-auditing`, `hash-record/check`.
