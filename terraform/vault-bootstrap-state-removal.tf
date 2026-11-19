removed {
  from = vault_kv_secret_v2.oci_credentials

  lifecycle {
    destroy = false
  }
}
