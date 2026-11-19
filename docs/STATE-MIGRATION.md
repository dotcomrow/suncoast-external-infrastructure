# HCP Terraform state migration

This runbook transfers ownership of the existing OCI PostgreSQL VM and its
supporting network resources from the `k8s-cms` HCP Terraform workspace to the
`suncoast-external-infrastructure` workspace without changing the real OCI
resources.

HashiCorp recommends `removed` and `import` blocks for new cross-state
migrations. This repository requires Terraform 1.7 or newer for that workflow.

## Non-negotiable rules

1. Never apply the target workspace while its plan proposes creating OCI
   resources.
2. Never apply source-side removal before the target import has completed and a
   zero-change target plan has been reviewed.
3. Lock the source workspace before the target begins tracking any of the same
   OCI objects. Keep it locked until the source state no longer contains them.
4. Preserve current state versions in HCP Terraform. They contain sensitive
   values and must not be downloaded to GitHub artifacts or committed.
5. Do not rename Terraform resource addresses during this migration.
6. Do not change OCI variables, VM shape, metadata, networking, NFS settings,
   or PostgreSQL bootstrap settings during this migration.

## Resources being transferred

Managed resource addresses in the source workspace:

```text
oci_core_vcn.directus_db
oci_core_internet_gateway.directus_db
oci_core_route_table.directus_db
oci_core_security_list.directus_db
oci_core_subnet.directus_db
oci_core_instance.directus_db
oci_core_public_ip.directus_db_reserved[0]   # when assign_public_ip=true
tls_private_key.db_tunnel[0]                 # when Terraform generated it
```

The instance boot volume is part of `oci_core_instance.directus_db`; it is not a
separate resource in this configuration. Data sources are recalculated and do
not move between states.

## Vault and sensitive values

The target workspace runs exclusively on the existing self-hosted HCP
Terraform agent pool. The agent supplies Vault connectivity and authentication;
no Vault token or application secret is stored in GitHub.

Existing Directus values are read from these Vault KV-v2 paths:

```text
secret/directus_db_database
secret/directus_db_user
secret/directus_db_password
secret/directus_db_ssh_private_key_b64
```

Each existing Directus path uses the `value` field. Terraform derives the
matching OpenSSH public key from the Vault private key, so the TLS private-key
resource is not recreated in the target workspace.

The OCI credentials historically exist in `K8S Cluster Variables`, not in
Vault. The initial workflow temporarily attaches that variable set and applies
the isolated `terraform-vault-bootstrap/` configuration. This writes the
values to:

```text
secret/external-infrastructure/oci
```

The normal configuration then reads OCI credentials from Vault. A `removed`
block forgets the one-time Vault bootstrap resource without deleting the
secret, and the broad Kubernetes variable set is detached automatically.

## Phase 1: create an inert target workspace

1. Review the committed workflows and Terraform configuration.
2. Run `./scripts/configure-repository.sh "HCP PROJECT NAME"` from this
   repository. This is the only bootstrap command; it replaces console setup.
3. The script sets `TFE_PROJECT`, enables the initial workflow if necessary,
   and dispatches it with its required confirmation.
4. The workflow copies the Terraform version and self-hosted agent pool from
   `k8s-cms`, creates the target workspace with auto-apply disabled, configures
   standard workspace variables, performs the isolated Vault bootstrap,
   detaches the migration variable set, and creates a speculative import plan.
5. The workflow disables itself only after all bootstrap steps succeed.
6. Review the reported import plan. Do not apply it unless it contains imports
   and the expected Vault bootstrap state removal only, with no OCI creates,
   updates, replacements, or deletions.

## Phase 2: capture and verify source identity

Run the `Audit HCP Terraform state migration` workflow. It reports workspace
metadata, variable names, variable-set names, managed OCI/TLS resource
addresses, and state-version identifiers without downloading raw state or
printing sensitive values.

In HCP Terraform, record the current source state version. In OCI, record the
existing VM OCID, reserved public-IP OCID, public IP address, private IP
address, VCN, subnet, route table, security list, and internet gateway.

Verify the VM and PostgreSQL are healthy before proceeding. This is the
rollback baseline.

## Phase 3: import into the target workspace

1. Lock the `k8s-cms` workspace.
2. Confirm it has no current or queued runs.
3. Copy `migration/imports.tf.example` into the target `terraform/` directory as
   `imports.tf`.
4. The migration data sources look up the existing OCI objects by their
   historical display names. Every lookup uses `one(...)` and therefore fails
   unless the match is unique. Compare the discovered IDs with the OCI values
   recorded in Phase 2.
5. Upload the target configuration and create a speculative plan.
6. The plan must contain imports only. It must contain zero create, update,
   replace, and delete operations against OCI.
7. Apply the reviewed import plan.
8. Remove `imports.tf` and create another speculative target plan.
9. The resulting plan must report no infrastructure changes.

The source remains locked during this temporary dual-state interval.

## Phase 4: make the source workspace forget the resources

Only after Phase 3 succeeds:

1. Remove the three `oci-directus-db*.tf` files, the OCI provider requirement,
   OCI template, OCI smoke test, and OCI documentation from `k8s-cms`.
2. Copy `migration/k8s-cms-removed-oci-resources.tf` into the source Terraform
   directory.
3. Create and review the source plan.
4. Every OCI/TLS action must say that Terraform will forget the object without
   destroying it. No OCI API mutation may be planned.
5. Apply the source plan.
6. Confirm none of the transferred addresses remain in the source state.
7. Confirm all expected addresses remain in the target state.
8. Run a fresh speculative plan in both workspaces. Both must be clean.
9. Unlock the source workspace.

The `removed` blocks may remain for at least one release as an auditable record
of the transfer and can be removed later.

## Rollback

If target import fails, do not touch the source state. Remove any partial target
imports and continue managing the VM from the locked source workspace.

If source removal has completed but target verification later fails, use HCP
Terraform's retained state versions to restore the last source state version,
then remove the corresponding target bindings before unlocking either
workspace. Restoring state changes Terraform ownership only; it must never be
paired with an OCI destroy operation.

## Completion evidence

Retain these run links and identifiers in the migration pull requests:

- source pre-migration state version;
- target import run;
- target zero-change run;
- source forget-only run;
- source zero-change run;
- post-migration VM OCID and reserved public-IP OCID comparison;
- PostgreSQL and NFS smoke-test results.
