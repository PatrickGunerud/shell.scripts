#!/bin/bash

for c in $(podman ps --format '{{.Names}}' | grep '^gh-runner'); do
  echo "==================== $c ===================="
  podman inspect "$c" --format '{{range .Config.Env}}{{println .}}{{end}}'
  echo
done