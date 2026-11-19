# Suncoast External Infrastructure

This repository owns durable infrastructure that exists independently of the
RKE2 platform and survives a complete platform rebuild.

The first managed system is the existing Oracle Cloud Infrastructure VM that
hosts PostgreSQL and the Directus uploads NFS export. The OCI configuration and
resource addresses were copied from `dotcomrow/k8s-cms` before state ownership
is moved; only canonical Terraform formatting was applied.
Historical Terraform names such as `directus_db` are intentionally retained
during the state migration to avoid combining an ownership change with a
resource-address refactor.

## Lifecycle boundary

- This repository and its HCP Terraform workspace create and manage external
  infrastructure.
- The RKE2 build does not run or mutate this Terraform configuration.
- Kubernetes and application repositories consume the resulting host, tunnel,
  and storage contracts.
- Each application remains responsible for safely creating or adopting its own
  database, role, schema, and forward-only migrations.

## Repository layout

- `terraform/` - OCI VM, networking, reserved public IP, PostgreSQL bootstrap,
  SSH tunnel identity, and Directus uploads NFS export.
- `docs/OCI-DIRECTUS-DB.md` - current VM operating documentation retained from
  the original repository.
- `docs/STATE-MIGRATION.md` - required no-destroy HCP Terraform state transfer
  procedure.
- `migration/` - reviewed import/removal templates used only during the one-time
  workspace transfer.
- `terraform-vault-bootstrap/` - one-time configuration that moves the
  existing OCI API credentials from the inherited HCP variable set into Vault.
- `.github/workflows/initial-deploy.yml` - scripted HCP project lookup,
  workspace creation, self-hosted agent-pool configuration, Vault credential
  bootstrap, and speculative import plan.
- `.github/workflows/terraform-deploy.yml` - standard ongoing Terraform plan,
  apply, and release workflow after migration.
- `scripts/configure-repository.sh` - configures the required GitHub project
  variable and dispatches the initial workflow without console configuration.

## Scripted bootstrap

No HCP Terraform workspace settings or Terraform input secrets are configured
by hand. From an authenticated `gh` CLI session, run:

```bash
./scripts/configure-repository.sh "HCP PROJECT NAME"
```

The script sets the repository `TFE_PROJECT` variable and dispatches the
initial workflow. That workflow:

1. resolves the existing HCP project exactly by name;
2. copies the Terraform version and self-hosted agent pool from `k8s-cms`;
3. creates an empty target workspace with auto-apply disabled;
4. creates the standard `project_name` and `org_name` workspace variables;
5. temporarily attaches `K8S Cluster Variables` to obtain the existing OCI
   values;
6. runs only the Vault bootstrap configuration on the self-hosted agent,
   writing the OCI credentials to `secret/external-infrastructure/oci`;
7. detaches the broad variable set;
8. reads ongoing OCI and Directus values directly from Vault; and
9. creates a speculative import plan without applying any OCI changes.

The initial workflow persists the detected agent-pool ID as the repository
variable `TFE_AGENT_POOL_ID`, then disables itself after it succeeds. Routine
deployments re-enforce that agent pool before every run.

## Safety

The existing OCI resources use `prevent_destroy = true`. The initial workflow
is manual-dispatch only and creates a speculative OCI import plan. It cannot
apply the OCI configuration. Routine applies remain blocked until the scripted
migration sets `STATE_MIGRATION_COMPLETE=true`.

Do not apply this repository against an empty workspace. First complete
`docs/STATE-MIGRATION.md` and prove that the target workspace plan contains no
resource creation, replacement, update, or deletion.
