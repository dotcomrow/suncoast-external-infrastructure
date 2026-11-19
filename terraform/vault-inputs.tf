provider "vault" {}

data "vault_kv_secret_v2" "oci_credentials" {
  mount = "secret"
  name  = "external-infrastructure/oci"
}

data "vault_kv_secret_v2" "directus_db_database" {
  mount = "secret"
  name  = "directus_db_database"
}

data "vault_kv_secret_v2" "directus_db_user" {
  mount = "secret"
  name  = "directus_db_user"
}

data "vault_kv_secret_v2" "directus_db_password" {
  mount = "secret"
  name  = "directus_db_password"
}

data "vault_kv_secret_v2" "directus_db_ssh_private_key_b64" {
  mount = "secret"
  name  = "directus_db_ssh_private_key_b64"
}

data "tls_public_key" "directus_db_tunnel" {
  private_key_openssh = base64decode(data.vault_kv_secret_v2.directus_db_ssh_private_key_b64.data.value)
}

locals {
  oci_tenancy_ocid     = trimspace(data.vault_kv_secret_v2.oci_credentials.data.tenancy_ocid)
  oci_user_ocid        = trimspace(data.vault_kv_secret_v2.oci_credentials.data.user_ocid)
  oci_fingerprint      = trimspace(data.vault_kv_secret_v2.oci_credentials.data.fingerprint)
  oci_private_key      = data.vault_kv_secret_v2.oci_credentials.data.private_key
  oci_region           = trimspace(data.vault_kv_secret_v2.oci_credentials.data.region)
  oci_compartment_ocid = trimspace(data.vault_kv_secret_v2.oci_credentials.data.compartment_ocid)

  db_name_effective               = trimspace(data.vault_kv_secret_v2.directus_db_database.data.value)
  directus_db_user_effective      = trimspace(data.vault_kv_secret_v2.directus_db_user.data.value)
  directus_db_password_effective  = data.vault_kv_secret_v2.directus_db_password.data.value
  db_tunnel_private_key_b64_vault = trimspace(data.vault_kv_secret_v2.directus_db_ssh_private_key_b64.data.value)
  db_tunnel_public_key_vault      = trimspace(data.tls_public_key.directus_db_tunnel.public_key_openssh)
}

check "vault_inputs_are_complete" {
  assert {
    condition = alltrue([
      length(local.oci_tenancy_ocid) > 0,
      length(local.oci_user_ocid) > 0,
      length(local.oci_fingerprint) > 0,
      length(trimspace(local.oci_private_key)) > 0,
      length(local.oci_region) > 0,
      length(local.oci_compartment_ocid) > 0,
      length(local.db_name_effective) > 0,
      length(local.directus_db_user_effective) > 0,
      length(local.directus_db_password_effective) >= 16,
      length(local.db_tunnel_private_key_b64_vault) > 0,
      length(local.db_tunnel_public_key_vault) > 0,
    ])
    error_message = "Required OCI, Directus database, or SSH tunnel values are missing from Vault."
  }
}
