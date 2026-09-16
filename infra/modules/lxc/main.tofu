terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.113.1"
    }
    random = {
      source  = "opentofu/random"
      version = "~> 3.6"
    }
    technitium = {
      source  = "darkhonor/technitium"
      version = "~> 1.2"
    }
  }
}

resource "random_password" "container_root" {
  length           = 24
  min_lower        = 2
  min_upper        = 2
  min_numeric      = 2
  min_special      = 2
  special          = true
  override_special = "_%@-"
}
resource "proxmox_virtual_environment_container" "this" {
  for_each = { for k, v in var.containers : k => v if v.present }

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

    type = each.value.ansible_os
  }

  environment_variables = { for v in each.value.environment_variables: v.key => v.value }

  initialization {
    entrypoint = each.value.entrypoint
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

resource "technitium_record" "containers" {
  for_each = var.technitium_register_records ? proxmox_virtual_environment_container.this : {}

  zone  = var.technitium_zone
  name  = "${replace(each.key, "_", "-")}.${var.technitium_zone}"
  type  = "A"
  value = split("/", each.value.initialization[0].ip_config[0].ipv4[0].address)[0]
  ttl   = 3600
}
