---
name: tool-writing
description: Write tool scripts with companion specs. Bash is the default; PowerShell is a legitimate alternative. Spec first, build, audit, repeat until PASS. Triggers - write a tool, create tool script, new bash script, build a tool, write shell script, tool spec.
---

## Language Tiers

| Tier | Language | When |
| --- | --- | --- |
| 1 (default) | **Bash** | Agent runtime default. Universally available wherever Git is installed. |
| 2 | **PowerShell** | Windows-native operations, complex object manipulation, or when PowerShell is more featured for the task. |
| 3 (future) | **C# scripts** (.NET `dotnet-script`) | High complexity or performance demands. Not in regular use yet. |
| 4 (future) | **Rust binary** | Distribution, concurrency, or performance requirements. Not in regular use yet. |

## Checklist

1. **Write spec first**: `<name>.spec.md` — purpose, params, output,
   errors, examples. No spec = suspect.
2. **Write script**: self-documenting param block, no hardcoded paths,
   no interactive input, works from any CWD. Default to Bash unless
   PowerShell is clearly more appropriate (document the choice in spec).
3. **Validate**: lint/static-check the script before moving on.
4. **Place it**: Skill-embedded (inside skill dir) if skill-specific.
   Standalone (`tools/`) if general-purpose.
5. **Hygiene**: run `markdownlint` on the spec. Zero errors before committing.
6. **Audit**: load `tool-auditing/SKILL.md` and follow its dispatch pattern to check spec alignment. Fix all findings, re-audit. **Repeat until PASS.**

## Conventions

- PowerShell: `$ErrorActionPreference = 'Continue'`, collect errors, `$PSScriptRoot` for paths
- Bash: `set -e`, fail-fast, `$(dirname "$0")` for paths
- Output: markdown for reports, JSON for data, plain text for status
- Never: hardcoded absolute paths, `Read-Host`, `read -p`, or `Get-Credential`
- Error handling: exit non-zero on failure; name the missing or invalid input in error messages; no partial output on non-zero exit

Related: `tool-auditing`, `skill-writing`, `spec-writing`
