// One-time recovery after the interrupted HCP Terraform apply created the
// volume in OCI but failed before persisting it in workspace state.
// Remove this import block after the import has completed successfully.
import {
  to = oci_core_volume.postgresql_data
  id = "ocid1.volume.oc1.iad.abuwcljrn276akos4ogb3as4dglzmm2bx532notyb57dmutkr4miq4fdyytq"
}

import {
  to = oci_core_volume_attachment.postgresql_data
  id = "ocid1.volumeattachment.oc1.iad.anuwcljrsflnnfacr3pfd3pzc2cljghdcobvfkr6xccnmgusayxvv5nenhaa"
}
