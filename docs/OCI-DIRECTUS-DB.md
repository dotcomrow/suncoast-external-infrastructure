# Oracle PostgreSQL VM

This repository owns the Oracle Cloud Infrastructure VM and durable storage
that remain available when the RKE2 platform is rebuilt. Historical Terraform
resource names containing `directus_db` are retained to preserve resource
addresses; the VM is the shared external PostgreSQL host for applications that
contain non-reproducible data.

## Managed architecture

- `VM.Standard.E4.Flex` Ubuntu VM.
- Existing 500 GB boot volume for the operating system, installed software,
  configuration, and the Directus uploads NFS export.
- Separate OCI block volume mounted at `/var/lib/postgresql` for database data.
- Reserved public IP and SSH-tunneled PostgreSQL connectivity.
- OCI network resources and the Directus uploads NFS export.
- Vault-provided OCI credentials, Directus database credentials, and the stable
  database-tunnel identity.

The separate PostgreSQL volume is protected by `prevent_destroy`. Its attachment
is intentionally replaceable so the same durable volume can be detached from a
retired VM and attached to a replacement VM.

## Budget development configuration

The defaults are sized for development traffic while keeping the total near the
current $50 monthly ceiling:

| Setting | Default | Purpose |
| --- | ---: | --- |
| `db_ocpus` | `1` | 1 OCPU / 2 x86 vCPUs |
| `db_memory_gbs` | `8` | Memory for several low-traffic databases |
| `db_baseline_utilization` | `BASELINE_1_8` | 12.5% sustained CPU billing with burst capacity |
| `db_boot_volume_size_gb` | `500` | Existing boot volume; unchanged |
| `postgresql_data_volume_size_gb` | `500` | Dedicated database capacity |
| `postgresql_data_volume_vpus_per_gb` | `0` | OCI Lower Cost performance for development |

At November 2026 public list prices, the incremental 500 GB Lower Cost volume is
about $12.75/month and the additional 6 GB RAM is about $8.61/month. Anchored to
the current approximately $25 bill, the estimated total is about $46.36/month
before taxes, backups, discounts, or credits.

Lower Cost changes performance, not persistence. At 500 GB it provides up to
approximately 1,000 IOPS and 120 MB/s. This is suitable for present development
traffic. Production traffic should be justified by measurements and normally
move the volume to Balanced performance.

## Scaling without replacement

- Increase `db_memory_gbs` or `db_ocpus` when observed usage requires it. Shape
  updates are in place but can reboot the VM.
- Change `postgresql_data_volume_vpus_per_gb` from `0` to `10` for Balanced
  performance. OCI updates the volume performance tier in place.
- Increase `postgresql_data_volume_size_gb` when capacity requires it. OCI grows
  the volume in place; volume size cannot be reduced.
- The first-boot/recovery script and an enabled systemd service run `resize2fs`
  so a rebuilt or rebooted VM adopts all provisioned capacity on the
  whole-device ext4 filesystem.

The current image ID and first-boot metadata are ignored for the running VM so a
new Ubuntu image or cloud-init template does not replace or unexpectedly mutate
it. CPU, memory, baseline utilization, and boot-volume size are no longer hidden
by `ignore_changes = all`, allowing reviewed in-place updates.

## Fresh-build and recovery behavior

Terraform creates the data volume in the same availability domain as the VM and
attaches it at the consistent path `/dev/oracleoci/oraclevdb`. Cloud-init then:

1. Waits for Terraform's volume attachment to appear.
2. Stops PostgreSQL before touching its data directory.
3. Formats the device only when it has no filesystem signature.
4. Copies the newly installed PostgreSQL cluster to a new blank volume.
5. Adopts an existing ext4 filesystem without formatting it.
6. Mounts the filesystem by UUID at `/var/lib/postgresql`.
7. Verifies that the expected PostgreSQL cluster exists.
8. Installs a systemd requirement that prevents PostgreSQL from starting when
   the dedicated mount is unavailable.
9. Creates the Directus role and database only when they do not already exist.

This fail-closed behavior prevents a rebuilt VM from silently creating a new
database cluster on its boot volume when the durable volume is missing.

## Connectivity

- PostgreSQL listens on localhost when `enable_db_ssh_tunnel=true`.
- Applications use SSH port forwarding to reach PostgreSQL without exposing
  port 5432 publicly.
- The stable tunnel key and database credentials are read from Vault by the
  existing self-hosted Terraform agent.
- Terraform writes the reserved public IP to
  `secret/directus_db_tunnel_host` and
  `secret/directus_db_ssh_tunnel_host`; applications therefore receive the
  current endpoint without a manual Vault update.
- NFS ingress is managed separately for the Directus uploads export.

## Deployment workflow

Pushes that change `terraform/**` create speculative HCP Terraform plans. They
do not apply automatically. An intentional apply uses the `Infra Deploy`
workflow with `apply=true` and confirmation phrase
`APPLY_EXTERNAL_INFRASTRUCTURE`.

Review the plan for these expected actions before applying the first storage and
shape update:

- One new OCI block volume.
- One new paravirtualized volume attachment.
- An in-place VM shape update.
- No VM, boot-volume, network, reserved-IP, or tunnel-key replacement.

After infrastructure deployment is complete, run:

```sh
cd terraform
./scripts/smoke-test-postgresql.sh
```

The smoke test validates tunnel authentication, PostgreSQL authentication, and
the expected database identity.
