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
auto-fixed.

If neither script can be run, apply the rules by hand in this order (mojibake first, because its sequences end in a curly quote):

1. Mojibake: U+00E2 U+20AC U+2122 and U+00E2 U+20AC U+02DC to `'`; U+00E2 U+20AC U+0153 to `"`; U+00E2 U+20AC U+201C to `-`; U+00E2 U+20AC U+201D to `--`; U+00E2 U+20AC U+00A2 to `-`; U+00E2 U+20AC U+00A6 to `...`. Flag, never replace, U+00C2 followed by a space.
2. Arrows: U+2192 to `->`, U+2190 to `<-`, U+2191 to `^`, U+2193 to `v`, U+2194 to `<->`, U+21D2 to `=>`, U+21D0 to `<=`, U+21D4 to `<=>`.
3. Dashes: U+2014 to `--`, U+2013 to `-`.
4. Quotes: U+2018 and U+2019 to `'`, U+201C and U+201D to `"`.
5. Ellipsis: U+2026 to `...`.
6. Bullets: U+2022, U+25E6, U+2023, U+25CF, U+25AA and U+25AB to `-`.

**Scripts** (relative to this folder):

- `scrub.sh` — Bash implementation.
- `scrub.ps1` — PowerShell 7+ implementation. Byte-identical stdout to
  `scrub.sh` for the same input.

Not wired into `markdown-hygiene` or any pre-commit hook.

Related: `tool-writing`, `tool-auditing`, `hash-record/check`.
