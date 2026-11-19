#!/usr/bin/env bash

set -euo pipefail

SOURCE_REPOSITORY="${1:-dotcomrow/k8s-cms}"

gh workflow run migrate-oci-state-out.yml \
  --repo "${SOURCE_REPOSITORY}" \
  --ref prod \
  -f confirmation=FORGET_OCI_STATE_NO_DESTROY

echo "Dispatched the guarded k8s-cms forget-only state migration"
