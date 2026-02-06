#!/usr/bin/env bash
set -euo pipefail

ACR_NAME="homereg"
ACR_SERVER="${ACR_NAME}.azurecr.io"
ACR_USERNAME="00000000-0000-0000-0000-000000000000"

# Ensure we're logged into Azure (interactive)
if ! az account show >/dev/null 2>&1; then
  az login >/dev/null
fi

# Get a fresh, short-lived token (raw string)
TOKEN="$(
  az acr login \
    --name "${ACR_NAME}" \
    --expose-token \
    --query accessToken \
    --output tsv
)"

if [[ -z "${TOKEN}" ]]; then
  echo "ERROR: token is empty" >&2
  exit 1
fi

printf "printf '%%s' '%s' | podman login %s --username %s --password-stdin\n" \
  "${TOKEN}" \
  "${ACR_SERVER}" \
  "${ACR_USERNAME}"
