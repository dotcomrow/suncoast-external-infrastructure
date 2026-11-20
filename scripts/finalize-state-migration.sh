#!/usr/bin/env bash

set -euo pipefail

GITHUB_REPOSITORY_NAME="${1:-}"
if [[ -z "${GITHUB_REPOSITORY_NAME}" ]]; then
  GITHUB_REPOSITORY_NAME="$(gh repo view --json nameWithOwner --jq '.nameWithOwner')"
fi

DISPATCHED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

gh workflow run finalize-state-migration.yml \
  --repo "${GITHUB_REPOSITORY_NAME}" \
  --ref prod \
  -f confirmation=FINALIZE_OCI_STATE_MIGRATION

RUN_ID=""
for _ in $(seq 1 60); do
  RUN_ID="$(
    gh run list \
      --repo "${GITHUB_REPOSITORY_NAME}" \
      --workflow finalize-state-migration.yml \
      --branch prod \
      --event workflow_dispatch \
      --limit 20 \
      --json databaseId,createdAt \
    | jq -r --arg dispatched_at "${DISPATCHED_AT}" \
        '[.[] | select(.createdAt >= $dispatched_at)] | sort_by(.createdAt) | reverse | .[0].databaseId // empty'
  )"
  [[ -n "${RUN_ID}" ]] && break
  sleep 2
done

[[ -n "${RUN_ID}" ]] || {
  echo "Could not identify the dispatched finalizer run" >&2
  exit 1
}

gh run watch "${RUN_ID}" --repo "${GITHUB_REPOSITORY_NAME}" --exit-status

# Repository Actions variables cannot be written by the built-in workflow token.
# Record completion only after the guarded finalizer run has succeeded, using the
# caller's authenticated GitHub CLI session.
gh variable set STATE_MIGRATION_COMPLETE \
  --repo "${GITHUB_REPOSITORY_NAME}" \
  --body true

echo "Final exclusive-ownership and zero-change verification passed"
echo "STATE_MIGRATION_COMPLETE=true"
