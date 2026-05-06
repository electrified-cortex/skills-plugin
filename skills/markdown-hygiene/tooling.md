# Markdown Hygiene — Tooling Options

Optional tools that can accelerate or replace manual hygiene. Not required — the skill works without them.

## markdownlint v2 (CLI)

If `markdownlint` v2 is already installed, skip manual audit and run it against the file. Zero output = clean.

Place a `.markdownlint.json` at the repo root to suppress project-standard exclusions (e.g. MD013, MD029, MD038).

## VS Code Extension

If the markdownlint VS Code extension is already active, violations are highlighted inline as you edit — no separate audit step needed.

## Note

These are options, not requirements. The dispatch skill works without either. If the tooling is already available, use it.
