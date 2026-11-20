resource "vault_kv_secret_v2" "directus_db_tunnel_host" {
  mount = "secret"
  name  = "directus_db_tunnel_host"

  data_json = jsonencode({
    value                   = local.db_host
    host                    = local.db_host
    directus_db_tunnel_host = local.db_host
  })
}

resource "vault_kv_secret_v2" "directus_db_ssh_tunnel_host" {
  mount = "secret"
  name  = "directus_db_ssh_tunnel_host"

  data_json = jsonencode({
    value                       = local.db_host
    host                        = local.db_host
    directus_db_ssh_tunnel_host = local.db_host
  })
}
