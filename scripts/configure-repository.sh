#!/usr/bin/env bash

set -euo pipefail

if [[ $# -gt 1 ]]; then
  echo "Usage: $0 [github-owner/repository]" >&2
  exit 1
fi

GITHUB_REPOSITORY_NAME="${1:-}"

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

gh workflow enable initial-deploy.yml --repo "${GITHUB_REPOSITORY_NAME}" || true
gh workflow run initial-deploy.yml \
  --repo "${GITHUB_REPOSITORY_NAME}" \
  --ref prod \
  -f confirmation=CREATE_MIGRATION_WORKSPACE

echo "Dispatched the scripted, plan-only migration bootstrap for ${GITHUB_REPOSITORY_NAME}"
