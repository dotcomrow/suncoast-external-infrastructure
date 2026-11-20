# Suncoast External Infrastructure

This repository owns durable infrastructure that exists independently of the
RKE2 platform and survives a complete platform rebuild.

The first managed system is the Oracle Cloud Infrastructure VM that hosts
PostgreSQL and the Directus uploads NFS export. Historical Terraform resource
names such as `directus_db` are retained because changing an address is an
independent state operation and provides no operational benefit.

## Lifecycle boundary

- This repository and its same-named HCP Terraform workspace manage external
  infrastructure.
- The RKE2 build does not run or mutate this Terraform configuration.
- Kubernetes and application repositories consume the host, tunnel, database,
  and storage contracts.
- Each application safely creates or adopts its own database, role, schema,
  and forward-only migrations.
- OCI credentials and application values are read from Vault by the existing
  self-hosted Terraform agent; they are not stored in GitHub.

## Repository layout

- `terraform/` - OCI VM, networking, reserved public IP, PostgreSQL bootstrap,
  SSH tunnel identity, and Directus uploads NFS export.
- `docs/OCI-DIRECTUS-DB.md` - current VM, PostgreSQL, NFS, and application
  connection documentation.
- `.github/workflows/terraform-deploy.yml` - standard Terraform plan, guarded
  apply, and release workflow.
- `.github/workflows/configure-workspace-project.yml` - assigns the workspace
  to the project selected by `TFE_PROJECT`.
- `scripts/configure-workspace-project.sh` - dispatches project reconciliation
  from an authenticated GitHub CLI session.

## Workspace standard

The HCP Terraform workspace name is the GitHub repository name. The HCP project
is selected by the repository variable `TFE_PROJECT`, and the self-hosted agent
pool is selected by `TFE_AGENT_POOL_ID`. Every deployment verifies and enforces
both settings before creating a Terraform run.

To reconcile the project assignment without running Terraform:

```bash
./scripts/configure-workspace-project.sh
```

## Deployments

Pushes that change `terraform/**` create speculative HCP Terraform plans.
Routine plans never apply automatically.

To perform an intentional apply, dispatch `Infra Deploy` with `apply=true` and
the confirmation phrase `APPLY_EXTERNAL_INFRASTRUCTURE`. Successful applies
create a repository release.

## Safety

The existing OCI resources use `prevent_destroy = true`, HCP Terraform
auto-apply is disabled, and the workflow requires an explicit apply request and
confirmation phrase. Review every applicable plan before dispatching it.

Do not point this configuration at a new or empty state while the existing OCI
resources still exist. Recover the retained HCP Terraform state first.
