# shell.scripts

A personal collection of self-contained Bash tools I keep on my `$PATH`:
dotfiles sync, an AI-assisted commit-message generator, GitHub Actions /
Azure Container Registry helpers, and network/PDF diagnostics. macOS-first,
with several tools that are also Linux/Raspberry-Pi aware.

## Install

The `dot-*` tools source their shared library by the **absolute path**
`$HOME/bin/lib/dot-common.sh` and call sibling scripts as `$HOME/bin/dot-*`,
so the scripts must live in `~/bin`. The simplest install is to clone the
repo directly there:

```bash
git clone git@github.com:PatrickGunerud/shell.scripts.git ~/bin
export PATH="$HOME/bin:$PATH"   # add to ~/.zshrc or ~/.bashrc to persist
```

`git-ai-commit` resolves its own library relative to itself, so it works
from any location; only the `dot-*` family requires the `~/bin` layout.

All scripts run under `#!/usr/bin/env bash` with `set -euo pipefail`.

## Tools

### Dotfiles sync — `dot-*`

Manifest-driven backup/restore of dotfiles between `$HOME` and the
`patrick.my.dotfiles` repo. Files to manage are listed one per line in
`~/.dotfiles-manifest`. SSH **private** keys are never copied; existing
files are backed up before being overwritten.

| Tool | Description | Example |
|------|-------------|---------|
| `dot-backup` | Copy manifest files from `$HOME` into the dotfiles repo (`managed/…`). | `dot-backup --dry-run` / `dot-backup --commit` |
| `dot-restore` | Restore files from the repo back to `$HOME`, backing up any existing copy under `~/.dotfiles-backups/<timestamp>/`. | `dot-restore --dry-run` |
| `dot-status` | Show repo `git status` plus per-entry live/repo presence. | `dot-status` |
| `dot-verify` | SHA-256 compare live files against the repo copies; non-zero exit on drift. | `dot-verify` |
| `dot-bootstrap` | Interactive first-run: restores dotfiles, symlinks VS Code settings, installs VS Code extensions. | `dot-bootstrap` |

**Dependencies:** `jq` and the VS Code CLI (`code`) for `dot-bootstrap`
extension install (both optional — skipped if absent). macOS-oriented
(VS Code `Library/` path).

### AI commit messages — `git-ai-commit`

Generates a Conventional Commits message for your **staged** changes,
including a Security/DevSecOps Impact section, via an AI backend. Runs a
blocking secret-scan on the staged diff and refuses to send it to the
backend if potential secrets are found. Installed as `git-ai-commit`, so it
works as a git subcommand: `git ai-commit`.

```bash
git ai-commit                 # generate message and commit (with confirmation)
git ai-commit --yes           # skip the confirmation prompt
git ai-commit --no-commit     # print the message only, do not commit
git ai-commit --json          # emit structured JSON (does not commit)
git ai-commit --full          # add the extended DevSecOps checklist
git ai-commit --no-verify     # pass --no-verify through to git commit
git ai-commit --print-prompt  # print the backend prompt and exit
git ai-commit --allow-secret-matches   # override the secret gate (confirmed false positives only)
```

**Dependencies:** `jq` (always), `perl` (always), plus one AI backend CLI.

**Backend selection** — set `AI_BACKEND`:

```bash
export AI_BACKEND=codex    # default; uses the `codex` CLI
export AI_BACKEND=claude   # uses the `claude` CLI
```

| Variable | Default | Purpose |
|----------|---------|---------|
| `CODEX_CMD` / `CODEX_ARGS` | `codex` / `exec --color never -` | Codex backend command |
| `CLAUDE_CMD` / `CLAUDE_ARGS` | `claude` / `-p` | Claude backend command |
| `AI_MAX_CHARS` | `120000` | Max diff size sent to the backend |
| `AI_LOG_TS` | `auto` | RFC 3339 timestamps on stderr (`auto`/`1`/`0`) |

### Standalone utilities

| Tool | Description | Example | Deps |
|------|-------------|---------|------|
| `gh-run-logs` | Interactive GitHub Actions run-log downloader; pick a run, save the full log to `~/Downloads`. | `gh-run-logs -R owner/repo -n 50` | `gh` (authenticated) |
| `scan-search` | Recursive case-insensitive text search inside OCR'd PDFs (`*.ocr.pdf`). | `scan-search "invoice" ~/Scans` | `pdfgrep` |
| `generate-accesToken.sh` | Mint a short-lived Azure Container Registry token and print a ready-to-run `podman login` command. | `generate-accesToken.sh` | `az`, `podman` |
| `gh-registation-token.sh` | Fetch a GitHub Actions runner registration token for the `PatrickGunerud` org. | `gh-registation-token.sh` | `gh` (authenticated) |
| `inspect-env-all-gh-runner.sh` | Dump the environment of every running `gh-runner*` Podman container. | `inspect-env-all-gh-runner.sh` | `podman` |
| `validate-windows-connectivity.sh` | Validate from macOS that Windows NCSI probes (DNS/HTTP/HTTPS) pass; useful when AdGuard filtering breaks Windows "internet" detection. | `validate-windows-connectivity.sh 172.20.10.27` | macOS `nslookup`, `curl`, `scutil` |

## Security note

`generate-accesToken.sh`, `gh-registation-token.sh`, and
`inspect-env-all-gh-runner.sh` **emit live credentials or secret-bearing
environment data on stdout by design.** Read them interactively — never
redirect their output into tracked files, logs, PRs, or chat transcripts.
See [SECURITY.md](SECURITY.md).

## License

Licensed under the [Apache License 2.0](LICENSE). See also [NOTICE](NOTICE).
