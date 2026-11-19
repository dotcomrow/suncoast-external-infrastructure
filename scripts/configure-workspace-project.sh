#!/usr/bin/env bash

set -euo pipefail

if [[ $# -gt 1 ]]; then
  echo "Usage: $0 [github-owner/repository]" >&2
  exit 1
fi

github_repository_name="${1:-}"
if [[ -z "${github_repository_name}" ]]; then
  github_repository_name="$(gh repo view --json nameWithOwner --jq '.nameWithOwner')"
fi

[[ "${github_repository_name}" == */* ]] || {
  echo "Repository must be in owner/name form" >&2
  exit 1
}

tfe_project="$(gh variable get TFE_PROJECT --repo "${github_repository_name}")"
[[ -n "${tfe_project}" ]] || {
  echo "TFE_PROJECT is not configured" >&2
  exit 1
}

gh workflow run configure-workspace-project.yml \
  --repo "${github_repository_name}" \
  --ref prod \
  -f confirmation=MOVE_WORKSPACE_TO_CONFIGURED_PROJECT

echo "Dispatched workspace assignment to HCP Terraform project ${tfe_project}"
