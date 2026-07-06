# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `NOTICE`, `SECURITY.md`, `CONTRIBUTING.md`, `CHANGELOG.md`, and `.gitignore`
  to establish standard open-source project hygiene.
- Filled the Apache 2.0 copyright line: `Copyright 2026 Patrick Gunerud`.

### Changed
- Rewrote `README.md` to reflect the current tool set, grouped by family
  (`dot-*`, `git-ai-commit`, standalones), with per-tool usage and
  dependencies.

### Removed
- Stale `README.md` references to the removed `git-ai-pr` tool and to the
  former `bin.git` install repo.

## [0.1.0] - 2026-07-05

Initial documented baseline. Summarized from `git log`.

### Added
- `git-ai-commit` — DevSecOps commit-message generator for staged changes
  with codex/claude backends, a blocking secret-scan gate, chatter
  guarding, subject-line validation, and machine-parseable RFC 3339
  timestamps on stderr.
- `dot-*` dotfiles suite (`dot-backup`, `dot-restore`, `dot-status`,
  `dot-verify`, `dot-bootstrap`) with the shared `lib/dot-common.sh`
  library and SSH-private-key safety belt.
- `gh-run-logs` — interactive GitHub Actions run-log downloader.
- `inspect-env-all-gh-runner.sh` — dump environment of `gh-runner*` Podman
  containers.
- `validate-windows-connectivity.sh` — macOS validator for Windows NCSI
  connectivity checks.
- `generate-accesToken.sh` and `gh-registation-token.sh` — Azure Container
  Registry and GitHub Actions runner token helpers.
- `scan-search` — recursive text search inside OCR'd PDFs.
- `CLAUDE.md` — repo-specific operator guidance.
