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

  environment_variables = { for v in each.value.environment_variables : v.key => v.value }

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
    name     = "eth0"
    bridge   = var.linux_bridge
    vlan_id  = each.value.vlan
    firewall = each.value.firewall != null
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

# --- Firewall (only for containers with a `firewall` block) ------------------

locals {
  firewalled = {
    for k, c in proxmox_virtual_environment_container.this : k => c
    if var.containers[k].firewall != null
  }
}

resource "proxmox_virtual_environment_firewall_options" "this" {
  for_each = local.firewalled

  node_name    = each.value.node_name
  container_id = each.value.vm_id

  enabled       = var.containers[each.key].firewall.enabled
  input_policy  = var.containers[each.key].firewall.input_policy
  output_policy = var.containers[each.key].firewall.output_policy
  log_level_in  = var.containers[each.key].firewall.log_level_in
  log_level_out = var.containers[each.key].firewall.log_level_out

  # anti-spoofing: the container may only send from its own MAC and its
  # configured IP (so it can't pose as e.g. traefik_dmz to an allowlist)
  macfilter = true
  ipfilter  = true
  dhcp      = var.containers[each.key].ipv4mode == "dhcp"
  ndp       = true  # IPv6 neighbour discovery
  radv      = false # containers have no business sending router adverts

  # rules first: enabling the firewall (default input DROP) before they
  # exist would cut the container off until the next apply step
  depends_on = [proxmox_virtual_environment_firewall_rules.this]
}

resource "proxmox_virtual_environment_firewall_rules" "this" {
  for_each = {
    for k, c in local.firewalled : k => c
    if length(var.containers[k].firewall.rules) > 0
  }

  node_name    = each.value.node_name
  container_id = each.value.vm_id

  dynamic "rule" {
    for_each = var.containers[each.key].firewall.rules

    content {
      type    = rule.value.type
      action  = rule.value.action
      source  = rule.value.source
      dest    = rule.value.dest
      proto   = rule.value.proto
      dport   = rule.value.dport
      macro   = rule.value.macro
      comment = rule.value.comment
      log     = rule.value.log
      iface   = "net0"
    }
  }
}
