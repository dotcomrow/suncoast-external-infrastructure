#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 <hcp-terraform-project-name> [github-owner/repository]" >&2
  exit 1
fi

TFE_PROJECT_NAME="$1"
GITHUB_REPOSITORY_NAME="${2:-}"

if [[ -z "${GITHUB_REPOSITORY_NAME}" ]]; then
  GITHUB_REPOSITORY_NAME="$(gh repo view --json nameWithOwner --jq '.nameWithOwner')"
fi

[[ "${GITHUB_REPOSITORY_NAME}" == */* ]] || {
  echo "Repository must be in owner/name form" >&2
  exit 1
}

default_branch="$(gh repo view "${GITHUB_REPOSITORY_NAME}" --json defaultBranchRef --jq '.defaultBranchRef.name')"
[[ "${default_branch}" == "prod" ]] || {
  echo "Expected default branch prod; found ${default_branch}" >&2
  exit 1
}

gh variable set TFE_PROJECT \
  --repo "${GITHUB_REPOSITORY_NAME}" \
  --body "${TFE_PROJECT_NAME}"

gh workflow enable initial-deploy.yml --repo "${GITHUB_REPOSITORY_NAME}" || true
gh workflow run initial-deploy.yml \
  --repo "${GITHUB_REPOSITORY_NAME}" \
  --ref prod \
  -f confirmation=CREATE_MIGRATION_WORKSPACE

echo "Configured TFE_PROJECT=${TFE_PROJECT_NAME} for ${GITHUB_REPOSITORY_NAME}"
echo "Dispatched the scripted, plan-only migration workspace bootstrap"
