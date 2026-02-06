#!/usr/bin/env bash
set -euo pipefail

OWNER="PatrickGunerud"
REPO="action-runner"

# Sanity check: ensure gh CLI is authenticated
gh auth status >/dev/null 2>&1 || {
  echo "ERROR: gh CLI is not authenticated. Run 'gh auth login' first." >&2
  exit 1
}

REGISTRATION_TOKEN="$(
  gh api -X POST "repos/${OWNER}/${REPO}/actions/runners/registration-token" \
    --jq '.token'
)"

echo "export REGISTRATION_TOKEN=${REGISTRATION_TOKEN}"
