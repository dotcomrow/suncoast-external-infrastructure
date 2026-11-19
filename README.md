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

## Safety

The existing OCI resources use `prevent_destroy = true`. The repository's HCP
Terraform workspace creation and deployment workflows are intentionally not
active yet. They must be adapted from the established `k8s-cms` GitHub Actions
process after the required GitHub repository variables are configured.

Do not apply this repository against an empty workspace. First complete
`docs/STATE-MIGRATION.md` and prove that the target workspace plan contains no
resource creation, replacement, update, or deletion.
