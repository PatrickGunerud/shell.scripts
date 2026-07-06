# CLAUDE.md — shell.scripts

Read `~/.claude/CLAUDE.md` before acting in this repo — it defines global conventions
not repeated here. This file is repo-specific guidance only. Repo:
`git@github.com:PatrickGunerud/shell.scripts.git`, default branch `main`.

## Repository purpose

A grab-bag of self-contained Bash tools kept on `$PATH`, macOS-first with several
Linux/Pi-aware pieces. The scripts span four loose themes: dotfiles sync between
`$HOME` and a Git repo, AI-assisted git tooling (commit-message generation), GitHub
runner / Azure Container Registry operations, and network/PDF diagnostics. Each script
is independently useful; two small script families share a sourced lib under `lib/`.

## Repository layout

| Path | What it does |
|------|--------------|
| `dot-backup` / `dot-restore` / `dot-status` / `dot-verify` / `dot-bootstrap` | Manifest-driven dotfiles sync between `$HOME` and the `patrick.my.dotfiles` repo. Read `~/.dotfiles-manifest`; back up before overwrite; **never touch SSH private keys**. |
| `lib/dot-common.sh` | Shared lib for the `dot-*` family: config vars, `log/warn/die`, manifest expansion, `is_ssh_private_key` safety belt. |
| `git-ai-commit` | DevSecOps commit-message generator for **staged** changes; codex/claude backend. Blocking secret-scan gate before sending any diff to a backend. |
| `lib/git-ai-common.sh` | Shared lib for `git-ai-*`: backend runner, platform detection, `preflight_check`, output cleanup. Sourced-only (refuses direct exec). |
| `gh-run-logs` | Interactive GitHub Actions run-log downloader (`gh` CLI). |
| `scan-search` | Recursive text search inside OCR'd PDFs (`pdfgrep`, `*.ocr.pdf`). |
| `generate-accesToken.sh` | Mint short-lived ACR token (`homereg.azurecr.io`), print a `podman login` line. |
| `gh-registation-token.sh` | Fetch a GH Actions runner registration token for org `PatrickGunerud`. |
| `inspect-env-all-gh-runner.sh` | Dump env of every `gh-runner*` Podman container. **Output is secret-bearing.** |
| `validate-windows-connectivity.sh` | Validate Windows NCSI probes from macOS (DNS/HTTP/HTTPS), e.g. against AdGuard at `172.20.10.27`. |
| `README.md` | End-user docs. Note: documents a `git-ai-pr` tool and `~/bin` (`bin.git`) install that this repo does not currently match — see below. |

## Script conventions specific to this repo

- **Shebang + strictness:** every script starts `#!/usr/bin/env bash` then `set -euo pipefail`. Never weaken this.
- **Arg parsing:** hand-rolled `while [[ $# -gt 0 ]]; do case "$1" in … esac; shift; done`; long+short flags; unknown flag → `die`. Value flags use `shift 2` (see `gh-run-logs`). Add new flags in that same block, keep `-h|--help` wired to `usage`.
- **Help text:** `usage()` heredoc (`cat <<'EOM'`); `gh-run-logs` instead reflects its own header comment block.
- **Output style — two patterns, pick by family:**
  - `dot-*`: human status on stdout via `log`, warnings/errors to stderr via `warn`/`die`; per-entry `[n]` counters + a summary tally line.
  - `git-ai-commit`: **stdout carries ONLY the payload** (commit message / JSON); ALL diagnostics go to stderr via `step`/`info`. Preserve this split — anything piped to `git commit -F -` must stay clean.
- **Error handling:** fail loud via `die`; wrap expected-nonzero commands (`nslookup`, `scutil`, `grep` with no match) in `|| true` with a comment saying why, so `set -e`/pipefail don't abort.
- **Shared-lib sourcing is inconsistent by design:** `dot-*` source `"$HOME/bin/lib/dot-common.sh"` (absolute — assumes install at `~/bin`); `git-ai-commit` sources `"$(dirname "$0")/lib/git-ai-common.sh"` (relative — runs from anywhere). Match the family you're editing; don't unify without asking.
- **Naming:** commands installed onto `$PATH` have no extension (`dot-backup`, `gh-run-logs`); ad-hoc utilities keep `.sh`. Existing filenames `generate-accesToken.sh` / `gh-registation-token.sh` are misspelled — leave them unless asked (renaming breaks callers/PATH).
- **Portability:** most tools are macOS-targeted (`scutil`, `brew`, VS Code `Library/` paths); `git-ai-common.sh` and the `gh-runner`/Podman scripts are Linux/Pi-aware. Prefer `printf` over `echo`; `git-ai-commit` uses `perl` (not `date %N`) for ms timestamps precisely for BSD/GNU portability.

## Dependencies and environment assumptions

External CLIs (not all required at once): `jq`, `codex`/`claude` (AI backend, `AI_BACKEND`), `gh`, `az` (Azure), `podman`, `pdfgrep`, `curl`, plus macOS `nslookup`/`scutil`/`code`. `git-ai-common.sh` self-reports install commands per platform on a missing dep.
Home-lab touchpoints: ACR `homereg.azurecr.io`; GitHub org `PatrickGunerud` + `gh-runner*` Podman containers; AdGuard/DNS `172.20.10.27`; dotfiles repo `patrick.my.dotfiles`.
Secrets/credentials: handled per `~/.claude/CLAUDE.md`. Note specifically: `generate-accesToken.sh`/`gh-registation-token.sh` **print live tokens to stdout**, and `inspect-env-all-gh-runner.sh` dumps secret-bearing env — never redirect their output into tracked files, logs, or transcripts.

## Testing and validation

No tests, linter config, or CI exist today. Before committing:
- `shellcheck <script>` on anything touched (proposed baseline — no `.shellcheckrc` yet; add one if we adopt it repo-wide).
- Use built-in `--dry-run` (`dot-backup`, `dot-restore`) and `--no-commit`/`--json`/`--print-prompt` (`git-ai-commit`) to exercise logic without side effects.
- `bash -n <script>` for a quick syntax check.
- Proposed minimal CI (ask before adding): a `.github/workflows/` job with `runs-on: gh-runner-build-*` that runs `shellcheck` against every script in the repo.

## Things Claude must NOT do in this repo

- **Do not execute scripts with real side effects during exploration** — `dot-restore`/`dot-backup` write to `$HOME` and can `git commit`; `generate-accesToken.sh`/`gh-registation-token.sh` mint live credentials; `inspect-env-all-gh-runner.sh` exposes secrets. Read them, or use `--dry-run`/`-h` only.
- **Never weaken `set -euo pipefail`** or strip an existing `|| true` guard without understanding the expected-failure it absorbs.
- **Do not break `git-ai-commit`'s stdout/stderr contract** or its secret-scan gate.
- **Do not "fix" the misspelled filenames** or unify the divergent lib-sourcing paths casually — both have downstream assumptions (`$PATH`, `~/bin`).
- Commit only what's staged; keep the mandatory Security/DevSecOps Impact section (per global CLAUDE.md). Do not stage/commit this file — the user handles that via `git-ai-commit`.
