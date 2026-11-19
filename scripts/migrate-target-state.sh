#!/usr/bin/env bash

set -euo pipefail

GITHUB_REPOSITORY_NAME="${1:-}"
if [[ -z "${GITHUB_REPOSITORY_NAME}" ]]; then
  GITHUB_REPOSITORY_NAME="$(gh repo view --json nameWithOwner --jq '.nameWithOwner')"
fi

gh workflow run migrate-target-state.yml \
  --repo "${GITHUB_REPOSITORY_NAME}" \
  --ref prod \
  -f confirmation=MIGRATE_OCI_STATE_NO_DESTROY

echo "Dispatched the guarded one-time OCI target-state migration"
