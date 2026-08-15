resource "random_password" "container_root" {
  length           = 24
  min_lower        = 2
  min_upper        = 2
  min_numeric      = 2
  min_special      = 2
  special          = true
  override_special = "_%@-"
}

terraform {
  backend "s3" {
    bucket       = "opentofu-state"
    key          = "homelab.tfstate"
    region       = "garage"
    use_lockfile = true

    endpoints = {
      s3 = "https://nas-2.nico"
    }

    insecure                    = true
    skip_region_validation      = true
    skip_credentials_validation = true
    use_path_style              = true
  }
}

data "proxmox_virtual_environment_nodes" "all" {}

locals {
  online_nodes = [
    for i, name in data.proxmox_virtual_environment_nodes.all.names :
    name if data.proxmox_virtual_environment_nodes.all.online[i]
  ]

  download_node = sort(local.online_nodes)[0]
}

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

resource "proxmox_download_file" "vm_image" {
  for_each = toset([for vm in var.vms : vm.image_file])

  content_type = "import"
  datastore_id = "synology"
  node_name    = local.download_node

  url       = "https://cloud.debian.org/images/cloud/bookworm/latest/${each.key}"
  file_name = each.key
}

resource "proxmox_virtual_environment_container" "this" {
  for_each = var.containers

  node_name = each.value.node
  vm_id     = each.value.ctid

  description = "Managed by OpenTofu: ${each.key}"

  tags = ["tofu-migrated"]

  # This corresponds to item.unprivileged | default(true)
  unprivileged = each.value.unprivileged

  # Equivalent to Ansible onboot: true
  start_on_boot = true

  cpu {
    # Equivalent to item.cores
    cores = each.value.cores

    # Closest bpg equivalent to item.cpus
    limit = each.value.cpus
  }

  memory {
    dedicated = each.value.memory
    swap      = "512"
  }

  disk {
    datastore_id = each.value.datastore_id
    size         = each.value.disk
  }

  operating_system {
    template_file_id = format(
      "%s:vztmpl/%s",
      var.cts_storage,
      each.value.image_name
    )

    type = "debian"
  }

  initialization {
    hostname = format(
      "%s%s",
      replace(each.key, "_", "-"),
      each.value.domain_name
    )

    ip_config {
      ipv4 {
        address = each.value.ipv4_address
        gateway = each.value.ipv4_gateway
      }
    }

    user_account {
      keys = [
        trimspace(file(var.ansible_key_file))
      ]

      password = random_password.container_root.result
    }
  }

  network_interface {
    name    = "eth0"
    bridge  = var.linux_bridge
    vlan_id = each.value.vlan
  }

  dynamic "features" {
    for_each = each.value.unprivileged ? [true] : []

    content {
      nesting = true
    }
  }

  dynamic "mount_point" {
    for_each = each.value.mounts

    content {
      path      = mount_point.value.path
      volume    = mount_point.value.volume
      size      = mount_point.value.size
      read_only = mount_point.value.read_only
      backup    = mount_point.value.backup
    }
  }

  dynamic "mount_point" {
    for_each = each.value.bind_mount == null ? [] : [each.value.bind_mount]

    content {
      path      = mount_point.value.target
      volume    = mount_point.value.source
      backup    = mount_point.value.backup
      read_only = false
    }
  }

  lifecycle {
    ignore_changes = [
      initialization,
      operating_system
    ]
  }
}