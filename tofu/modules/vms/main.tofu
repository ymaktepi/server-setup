terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.113.1"
    }
    technitium = {
      source  = "darkhonor/technitium"
      version = "~> 1.2"
    }
  }
}

resource "proxmox_download_file" "image" {
  for_each = var.images

  content_type       = "import"
  datastore_id       = var.image_datastore
  node_name          = var.download_node
  url                = each.value.url
  file_name          = basename(each.value.url)
  checksum           = each.value.checksum
  checksum_algorithm = each.value.checksum_algorithm
  overwrite          = false
}

resource "proxmox_virtual_environment_file" "user_data" {
  for_each = { for k, v in var.vms : k => v if v.user_data_file_id == null }

  content_type = "snippets"
  datastore_id = var.snippets_datastore
  node_name    = each.value.node

  source_raw {
    file_name = "tofu-${each.key}-user.yml"
    data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
      hostname = replace(each.key, "_", "-")
      fqdn     = "${replace(each.key, "_", "-")}${each.value.domain_name}"
      user     = each.value.cloud_init_user
      ssh_key  = trimspace(file(var.ansible_key_file))
      timezone = var.timezone
      locale   = var.locale
    })
  }
}

resource "proxmox_virtual_environment_vm" "this" {
  for_each = var.vms

  node_name = each.value.node
  vm_id     = each.value.vmid
  name      = each.key

  description = "Managed by OpenTofu: ${each.key}"
  tags        = ["tofu-migrated"]

  started = each.value.started
  on_boot = each.value.on_boot

  machine       = each.value.machine
  scsi_hardware = "virtio-scsi-single"
  boot_order    = ["scsi0"]

  cpu {
    type    = "host"
    cores   = each.value.cores
    sockets = 1
  }

  memory {
    dedicated = each.value.memory
    floating  = 0 # no ballooning (needed for PCIe passthrough anyway)
  }

  agent {
    enabled = true
  }

  vga {
    type = "serial0"
  }

  serial_device {
    device = "socket"
  }

  network_device {
    bridge      = var.linux_bridge
    model       = "virtio"
    vlan_id     = each.value.vlan
    mac_address = each.value.mac_address
    firewall    = true
  }

  disk {
    interface    = "scsi0"
    datastore_id = each.value.datastore_id
    import_from  = each.value.image == null ? null : proxmox_download_file.image[each.value.image].id
    file_format  = "raw"
    size         = each.value.disk_size
    iothread     = true
  }

  initialization {
    datastore_id = each.value.datastore_id
    interface    = "ide2"
    user_data_file_id = (
      each.value.user_data_file_id != null
      ? each.value.user_data_file_id
      : proxmox_virtual_environment_file.user_data[each.key].id
    )

    ip_config {
      ipv4 {
        address = each.value.ipv4mode == "static" ? each.value.ipv4_address : "dhcp"
        gateway = each.value.ipv4mode == "static" ? each.value.ipv4_gateway : null
      }
    }
  }

  operating_system {
    type = "l26"
  }

  dynamic "hostpci" {
    for_each = each.value.hostpci

    content {
      device  = "hostpci${hostpci.key}"
      mapping = hostpci.value.mapping
      id      = hostpci.value.id
      pcie    = hostpci.value.pcie
      rombar  = hostpci.value.rombar
    }
  }

  lifecycle {
    # cloud-init only matters at first boot; the disk source only at creation
    ignore_changes = [initialization, disk[0].import_from]
  }
}

resource "technitium_record" "vms" {
  # static VMs only: a DHCP VM's address isn't known here
  for_each = var.technitium_register_records ? { for k, v in var.vms : k => v if v.ipv4mode == "static" } : {}

  zone  = var.technitium_zone
  name  = "${replace(each.key, "_", "-")}.${var.technitium_zone}"
  type  = "A"
  value = split("/", each.value.ipv4_address)[0]
  ttl   = 3600
}
