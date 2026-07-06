# Security Policy

This is a personal tooling repository provided as-is, with **no formal
support or guaranteed response time**.

## Reporting

Report suspected security issues via a
[GitHub issue](https://github.com/PatrickGunerud/shell.scripts/issues).
Please do not include real secrets, tokens, or credentials in the report.

## Secret-bearing output

Some scripts emit live credentials or secret-bearing data on **stdout by
design**:

- `generate-accesToken.sh` — prints a live Azure Container Registry token.
- `gh-registation-token.sh` — prints a live GitHub Actions runner
  registration token.
- `inspect-env-all-gh-runner.sh` — dumps full container environments, which
  may include injected tokens.

Never redirect their output into tracked files, logs, PRs, issues, or chat
transcripts. Treat their output as sensitive.
