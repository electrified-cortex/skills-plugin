---
name: gh-cli-setup
description: Install, authenticate, and configure the GitHub CLI. Prerequisite for all other gh-cli skills. Triggers - install gh CLI, authenticate github CLI, gh auth login, setup github CLI, configure gh.
---

Install, auth, configure `gh`. Prereq — all other gh-cli skills depend on this.

Check install: `gh --version`. Not found → install:

```bash
# Windows
winget install --id GitHub.cli

# macOS
brew install gh

# Linux (Debian/Ubuntu)
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list
sudo apt update && sudo apt install gh
```

Auth — interactive (local dev, browser available):

```bash
gh auth login
```

Follow prompts → GitHub.com or GitHub Enterprise.

Auth — token (CI/automation, no browser):

```bash
echo "$GH_TOKEN" | gh auth login --with-token
```

Never hard-code token. Set `GH_TOKEN` as env var or CI secret before invoking.

Verify auth:

```bash
gh auth status
```

Success shows hostname, authenticated username, token scopes.

Config for automation:

```bash
gh config set git_protocol ssh
gh config set prompt disabled
```

Default repo:

```bash
gh repo set-default owner/repo
```

Suppresses `--repo` per-command in specific repo context.

GitHub Enterprise: add `--hostname enterprise.internal` to `gh auth login`.

Scope: covers `gh auth`, `gh config`, `gh repo set-default` only. Doesn't cover domain-specific subcommands, token mgmt beyond `gh auth`, or CI/CD pipeline config.

## Outputs

- Verification result: authenticated user display name + scopes.
- Exit status: 0 = success, non-zero = failure.

## Error Handling

- Wrong token: `gh auth status` will fail — re-run `gh auth login`.
- Network error: check connectivity, then retry.
- Stale token: scopes may have changed — re-authenticate.
