# Overview
This repo contains shell scripts/tools that I have found to be useful

## Tools

### `git-ai-commit`

Generates a [Conventional Commits](https://www.conventionalcommits.org/) message for your staged changes, including security impact analysis and testing notes.

```bash
git ai-commit              # generate and commit with confirmation
git ai-commit --yes        # skip confirmation prompt
git ai-commit --json       # output JSON only (no commit)
git ai-commit --no-commit  # preview the message without committing
git ai-commit --full       # include extended DevSecOps checklist
git ai-commit --no-verify  # pass --no-verify to git commit
```

If nothing is staged, the tool will offer to run `git add -A` before proceeding.

### `git-ai-pr`

Generates a squash merge commit message / PR summary for your branch against a base ref.

```bash
git ai-pr                          # summarize current branch vs auto-detected base
git ai-pr --base origin/develop    # specify a custom base ref
git ai-pr --json                   # output JSON only
git ai-pr --full                   # include extended DevSecOps checklist
git ai-pr --create-draft           # push and create a GitHub draft PR via gh
git ai-pr --no-push                # skip pushing when creating a draft PR
git ai-pr --no-diff                # omit the diff from the prompt
git ai-pr --no-commits             # omit the commit list from the prompt
```

Supports piped input:

```bash
git diff main..HEAD | git ai-pr
```

## Installation

1. Clone the repository and add it to your `PATH`:

```bash
git clone https://github.com/PatrickGunerud/bin.git ~/bin
export PATH="$HOME/bin:$PATH"
```

Add the `export` line to your shell profile (`~/.zshrc`, `~/.bashrc`, etc.) to make it permanent.

2. Install dependencies:

| Dependency | Required by | Install |
|---|---|---|
| [jq](https://jqlang.github.io/jq/) | all `git-ai-*` tools | `brew install jq` |
| [Codex CLI](https://github.com/openai/codex) | `AI_BACKEND=codex` (default) | `npm install -g @openai/codex` |
| [Claude CLI](https://docs.anthropic.com/en/docs/claude-cli) | `AI_BACKEND=claude` | `npm install -g @anthropic-ai/claude-code` |
| [gh](https://cli.github.com/) | `--create-draft` flag | `brew install gh` |

## Configuration

### Backend selection

Set the `AI_BACKEND` environment variable to choose your LLM provider:

```bash
export AI_BACKEND=codex   # default
export AI_BACKEND=claude
```

### Backend customization

| Variable | Default | Description |
|---|---|---|
| `CODEX_CMD` | `codex` | Codex CLI binary |
| `CODEX_ARGS` | `exec --color never -` | Arguments passed to Codex |
| `CLAUDE_CMD` | `claude` | Claude CLI binary |
| `CLAUDE_ARGS` | `-p` | Arguments passed to Claude |
| `AI_MAX_CHARS` | `120000` | Max diff size sent to the backend |

### PR-specific settings

| Variable | Default | Description |
|---|---|---|
| `AI_PR_REMOTE` | `origin` | Git remote used for push/PR creation |
| `AI_PR_BASE` | auto-detected | Override the base branch for PRs |
| `AI_PR_PUSH` | `1` | Set to `0` to disable auto-push |

## What it does

Both tools send your diff and repository context to the selected AI backend and produce a structured commit message following Conventional Commits format:

```
type(scope): subject <= 72 chars

- Bullet summary of changes

Security/DevSecOps Impact:
- Scanned for hardcoded secrets, IAM/RBAC changes, etc.

Testing:
- Relevant testing notes
```

The tools automatically scan your diff for:
- Potential secrets (API keys, tokens, passwords, private keys)
- Permission and IAM changes (roles, RBAC, service accounts, OIDC)

Use `--full` to add an extended DevSecOps checklist covering AuthN/AuthZ, supply chain, CI/CD, IaC, logging/PII, and network exposure.

Use `--json` to get structured JSON output for integration with other tools.

## Other utilities

| Script | Description |
|---|---|
| `generate-accesToken.sh` | Generate a short-lived Azure Container Registry token and print a `podman login` command |
| `gh-registation-token.sh` | Fetch a GitHub Actions runner registration token via `gh` CLI |

## License

[Apache License 2.0](LICENSE)
