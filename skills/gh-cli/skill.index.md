# gh-cli - skill index

Routes GitHub CLI tasks to the correct domain sub-skill; does not run gh commands itself.

## gh-cli

GitHub CLI operations hub that routes to domain-specific sub-skills via dispatch.

## gh-cli-actions

Triggers, monitors, and manages GitHub Actions workflows, runs, secrets, and variables via the CLI.

## gh-cli-api

Makes authenticated REST and GraphQL calls to the GitHub API when no dedicated gh subcommand covers the operation.

## gh-cli-issues

Manages GitHub issues through the full lifecycle — create, list, view, edit, comment, close — using the gh issue subcommand.

## gh-cli-pr

Entry point for pull request management via the GitHub CLI, handling inspection and routing write operations to sub-skills.

## gh-cli-projects

Creates and manages GitHub Projects v2 boards, items, and fields via the CLI.

## gh-cli-releases

Manages GitHub releases through the full lifecycle — create, publish, upload assets, edit, delete — via gh release.

## gh-cli-repos

Creates, clones, forks, syncs, edits, and deletes GitHub repositories via the CLI.

## gh-cli-setup

Installs, authenticates, and configures the GitHub CLI; prerequisite for all other gh-cli skills.
