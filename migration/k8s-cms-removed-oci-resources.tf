# Add this file to k8s-cms/terraform only after the target workspace has
# imported every OCI resource and produced a zero-change plan.

removed {
  from = oci_core_vcn.directus_db

  lifecycle {
    destroy = false
  }
}

removed {
  from = oci_core_internet_gateway.directus_db

  lifecycle {
    destroy = false
  }
}

removed {
  from = oci_core_route_table.directus_db

  lifecycle {
    destroy = false
  }
}

removed {
  from = oci_core_security_list.directus_db

  lifecycle {
    destroy = false
  }
}

removed {
  from = oci_core_subnet.directus_db

  lifecycle {
    destroy = false
  }
}

removed {
  from = oci_core_instance.directus_db

  lifecycle {
    destroy = false
  }
}

removed {
  from = oci_core_public_ip.directus_db_reserved

  lifecycle {
    destroy = false
  }
}

removed {
  from = tls_private_key.db_tunnel

  lifecycle {
    destroy = false
  }
}
