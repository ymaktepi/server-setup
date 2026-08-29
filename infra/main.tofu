
# todo: looks like proxmox/dns issue
#resource "proxmox_download_file" "debian_12_ct" {
#  for_each = toset([
#    for container in var.containers : container.image_name
#  ])
#  content_type = "vztmpl"
#  datastore_id = "synology"
#  node_name    = local.download_node
#
#  url = "https://download.proxmox.com/images/system/${each.key}"
#}
#
#resource "proxmox_download_file" "vm_image" {
#  for_each = toset([for vm in var.vms : vm.image_file])
#
#  content_type = "import"
#  datastore_id = "synology"
#  node_name    = local.download_node
#  overwrite    = false
#
#  url       = "https://cloud.debian.org/images/cloud/bookworm/latest/${each.key}"
#  file_name = each.key
#}
