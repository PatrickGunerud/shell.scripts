#!/usr/bin/env bash
# == gh-registation-token.sh ==
set -euo pipefail

ORG="PatrickGunerud"

# Sanity check: ensure gh CLI is authenticated
gh auth status >/dev/null 2>&1 || {
  echo "ERROR: gh CLI is not authenticated. Run 'gh auth login' first." >&2
  exit 1
}

REGISTRATION_TOKEN="$(
  gh api -X POST "orgs/${ORG}/actions/runners/registration-token" \
    --jq '.token'
)"

echo "export REGISTRATION_TOKEN=${REGISTRATION_TOKEN}"
