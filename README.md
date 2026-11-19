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
- `scripts/configure-repository.sh` - dispatches the initial workflow without
  console configuration.
- `scripts/migrate-target-state.sh` - locks `k8s-cms`, validates an import-only
  plan, applies it, and proves that the target state is clean.
- `scripts/migrate-source-state.sh` - dispatches the guarded `k8s-cms`
  forget-only run after its OCI source files are removed.
- `scripts/finalize-state-migration.sh` - proves exclusive ownership and a
  final zero-change target plan before enabling routine applies.
- `scripts/configure-workspace-project.sh` - assigns the existing HCP Terraform
  workspace to the project selected by the repository variable `TFE_PROJECT`.

## Scripted bootstrap

No HCP Terraform workspace settings or Terraform input secrets are configured
by hand. From an authenticated `gh` CLI session, run:

```bash
./scripts/configure-repository.sh
```

The HCP Terraform workspace name is derived from the GitHub repository name.
The HCP project is selected by the standard repository variable `TFE_PROJECT`.
For this repository it is `Suncoast Systems K8s Cluster`. The script dispatches
the initial workflow, which:

1. resolves exactly one existing HCP project named by `TFE_PROJECT`;
2. copies the Terraform version and self-hosted agent pool from `k8s-cms`;
3. creates or moves the repository-named workspace into that project with
   auto-apply disabled;
4. creates the standard `project_name` and `org_name` workspace variables;
5. temporarily places the empty workspace in the source project so it can use
   the project-scoped `K8S Cluster Variables` values;
6. runs only the Vault bootstrap configuration on the self-hosted agent,
   writing the OCI credentials to `secret/external-infrastructure/oci`;
7. removes any temporary credential access and restores the workspace to the
   project selected by `TFE_PROJECT`;
8. reads ongoing OCI and Directus values directly from Vault through the
   standard project variables; and
9. creates a speculative import plan without applying any OCI changes.

The initial workflow verifies that the standard inherited organization variable
`TFE_AGENT_POOL_ID` matches the source workspace, then disables itself after it
succeeds. Routine deployments re-enforce both `TFE_PROJECT` and that agent pool
before every run.

To reconcile only the HCP project assignment without running a Terraform plan:

```bash
./scripts/configure-workspace-project.sh
```

After reviewing the initial speculative plan, run:

```bash
./scripts/migrate-target-state.sh
```

The migration workflow refuses to apply if HCP reports any Terraform adds,
changes, or destroys. It leaves `k8s-cms` locked after a successful import so
the source forget-only phase can run without dual ownership races.

After the committed `k8s-cms` source removal is reviewed, the remaining
scripted commands are:

```bash
./scripts/migrate-source-state.sh
./scripts/finalize-state-migration.sh
```

Migration-only workflows, the Vault bootstrap directory, import templates,
and source removal workflow are deleted after final verification. The normal
Terraform deployment workflow and Vault-backed external-resource configuration
remain.

## Safety

The existing OCI resources use `prevent_destroy = true`. The initial workflow
is manual-dispatch only and creates a speculative OCI import plan. It cannot
apply the OCI configuration. Routine applies remain blocked until the scripted
migration sets `STATE_MIGRATION_COMPLETE=true`.

Do not apply this repository against an empty workspace. First complete
`docs/STATE-MIGRATION.md` and prove that the target workspace plan contains no
resource creation, replacement, update, or deletion.
