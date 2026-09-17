# fixme
#resource "proxmox_virtual_environment_vm" "this" {
#  for_each = var.vms
#
#  node_name = each.value.node
#  vm_id     = each.value.vmid
#  name      = each.value.name
#
#  description = "Managed by OpenTofu: ${each.key}"
#  tags        = ["tofu-migrated"]
#
#  cpu {
#    type    = "host"
#    cores   = each.value.cores
#    sockets = 1
#  }
#
#  memory {
#    dedicated = each.value.memory
#    floating  = each.value.memory
#  }
#
#  machine = each.value.gpu ? "q35" : null
#
#  scsi_hardware = "virtio-scsi-single"
#
#  agent {
#    enabled = true
#  }
#
#  vga {
#    type = "serial0"
#  }
#
#  serial_device {
#    device = "socket"
#  }
#
#  network_device {
#    bridge   = var.linux_bridge
#    model    = "virtio"
#    vlan_id  = each.value.vlan
#    firewall = true
#  }
#
#  disk {
#    interface    = "scsi0"
#    datastore_id = "synology"
#    import_from  = local.vm_image_ids[each.key]
#
#    file_format = "qcow2"
#    size        = each.value.disk_size
#    iothread    = true
#  }
#
#  initialization {
#    datastore_id = "synology"
#    interface    = "ide2"
#
#    ip_config {
#      ipv4 {
#        address = each.value.ipv4mode == "static" ? each.value.ipv4_address : "dhcp"
#
#        gateway = each.value.ipv4mode == "static" ? each.value.ipv4_gateway : null
#      }
#    }
#  }
#
#  boot_order = ["scsi0"]
#
#  operating_system {
#    type = "l26"
#  }
#
#  on_boot = false
#
#  # Optional GPU passthrough.
#  dynamic "hostpci" {
#    for_each = each.value.gpu ? [
#      {
#        device = "hostpci0"
#        id     = "01:00.0"
#        pcie   = true
#        rombar = false
#      },
#      {
#        device = "hostpci1"
#        id     = "01:00.1"
#        pcie   = true
#        rombar = null
#      }
#    ] : []
#
#    content {
#      device = hostpci.value.device
#      id     = hostpci.value.id
#      pcie   = hostpci.value.pcie
#      rombar = hostpci.value.rombar
#    }
#  }
#  lifecycle {
#    ignore_changes = [initialization]
#  }
#}
