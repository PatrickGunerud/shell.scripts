# Contributing

This is a personal repository, but issues and pull requests are welcome.

## Conventions

- **Bash:** every script starts with `#!/usr/bin/env bash` and
  `set -euo pipefail`. Do not weaken strict mode.
- **Lint:** run `shellcheck` on any script you touch before committing;
  fix or explicitly justify each finding.
- **`git-ai-commit` stdout/stderr contract:** stdout carries only the
  payload (the commit message or `--json` output); all diagnostics go to
  stderr. Keep this split intact so piped output stays clean.
- **Commits:** stage exactly what you intend to commit — no `git add -A` /
  `git add .`. Commit messages include a Security/DevSecOps Impact section.
- **Secret hygiene:** never commit tokens, keys, or credentials. Be aware
  that some scripts emit secrets on stdout (see [SECURITY.md](SECURITY.md)).

## Licensing

Contributions are accepted under the [Apache License 2.0](LICENSE)
(standard inbound = outbound licensing). By submitting a change you agree it
may be distributed under those terms.
