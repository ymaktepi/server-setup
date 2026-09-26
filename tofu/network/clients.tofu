# DHCP reservations (fixed IPs) and their local DNS names. Keyed by a stable
# slug; `name` is the controller's display alias (null where none is set).
#
# skip_forget_on_destroy: removing an entry here only drops the reservation
# from tofu - it doesn't make the controller forget the device's history.
locals {
  clients = {
    # --- Default (10.10.0.0/23) ---
    netgear_switch = { mac = "54:07:7d:1d:fa:d1", name = "Netgear GS108Ev4", fixed_ip = "10.10.0.99", dns = "netgear.nico" }
    nico_pi        = { mac = "2c:cf:67:30:48:c5", name = "nico-pi", fixed_ip = "10.10.0.11", dns = "pi.nico" }
    proxmox1       = { mac = "74:56:3c:e6:6c:bd", name = null, fixed_ip = "10.10.0.100", dns = "proxmox.nico" }
    proxmox2       = { mac = "98:fa:9b:82:61:fb", name = "proxmox2", fixed_ip = "10.10.0.101", dns = "node2.nico" }
    proxmox3       = { mac = "f8:75:a4:9b:85:fa", name = "proxmox3", fixed_ip = "10.10.0.103", dns = "node3.nico" }
    pbs            = { mac = "98:fa:9b:82:6a:43", name = "pbs", fixed_ip = "10.10.0.105", dns = "pbs.nico" }
    sarah_nas      = { mac = "00:11:32:3d:1f:48", name = "sarah-nas", fixed_ip = "10.10.0.200", dns = "nas.sarah" }
    minix          = { mac = "a0:1e:0b:14:af:39", name = null, fixed_ip = "10.10.0.201", dns = "minix.nico" }
    synology_nic2  = { mac = "90:09:d0:56:92:12", name = null, fixed_ip = "10.10.0.251", dns = "nas-2.nico" } # Garage S3 (tofu state backend)
    synology_nic1  = { mac = "90:09:d0:56:92:11", name = null, fixed_ip = "10.10.0.252", dns = "nas-1.nico" }

    # --- Guest (10.10.3.0/24) ---
    prusa_mini = { mac = "08:3a:8d:ce:16:db", name = null, fixed_ip = "10.10.3.195", dns = "prusa.nico" }

    # --- Crusted (10.10.4.0/24) ---
    mystrom_main   = { mac = "b4:8a:0a:b5:33:00", name = "mystrom main", fixed_ip = "10.10.4.48", dns = null }
    mystrom_pc     = { mac = "08:3a:8d:94:3e:4c", name = "msytrom PC", fixed_ip = "10.10.4.54", dns = null }
    mystrom_server = { mac = "c8:f0:9e:be:12:10", name = "mystrom server", fixed_ip = "10.10.4.103", dns = null }
  }
}

resource "unifi_client" "this" {
  for_each = local.clients

  mac              = each.value.mac
  name             = each.value.name
  fixed_ip         = each.value.fixed_ip
  local_dns_record = each.value.dns

  skip_forget_on_destroy = true
}
