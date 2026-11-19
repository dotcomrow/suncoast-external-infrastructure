resource "vault_kv_secret_v2" "oci_credentials" {
  mount = "secret"
  name  = "external-infrastructure/oci"

  data_json = jsonencode({
    tenancy_ocid     = var.oci_tenancy_ocid
    user_ocid        = var.oci_user_ocid
    fingerprint      = var.oci_fingerprint
    private_key      = var.oci_private_key
    region           = var.oci_region
    compartment_ocid = var.oci_compartment_ocid
  })

  lifecycle {
    prevent_destroy = true
  }
}

output "vault_oci_secret_path" {
  value = "secret/external-infrastructure/oci"
}
