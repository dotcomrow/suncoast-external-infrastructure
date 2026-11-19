#!/usr/bin/env bash

set -euo pipefail

GITHUB_REPOSITORY_NAME="${1:-}"
if [[ -z "${GITHUB_REPOSITORY_NAME}" ]]; then
  GITHUB_REPOSITORY_NAME="$(gh repo view --json nameWithOwner --jq '.nameWithOwner')"
fi

gh workflow run finalize-state-migration.yml \
  --repo "${GITHUB_REPOSITORY_NAME}" \
  --ref prod \
  -f confirmation=FINALIZE_OCI_STATE_MIGRATION

echo "Dispatched final exclusive-ownership and zero-change verification"
