#!/usr/bin/env bash
set -euo pipefail

# inspect-env-all-gh-runner.sh
#
# Purpose:
#   Dump the environment (.Config.Env) of every running Podman container
#   whose name starts with "gh-runner", one labeled block per container.
#
# ⚠️  SECURITY WARNING:
#   Output includes the FULL container environment, which may contain
#   injected secrets/tokens (registration tokens, API keys, etc.).
#   Treat output as sensitive: do NOT paste into logs, PRs, issues,
#   or chat transcripts.
#
# Usage:
#   inspect-env-all-gh-runner.sh
#
# Requirements:
#   podman (read-only access; uses `podman ps` and `podman inspect`)

while IFS= read -r c; do
  echo "==================== ${c} ===================="
  podman inspect "$c" --format '{{range .Config.Env}}{{println .}}{{end}}'
  echo
done < <(podman ps --format '{{.Names}}' | grep '^gh-runner' || true)