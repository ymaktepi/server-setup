# Subnets/gateways match the network_testing_* containers in core/main.tofu,
# which probe the isolation between these VLANs. `name` must match the
# controller's existing network name exactly: the import blocks in
# imports.tofu look networks up by it.
locals {
  networks = {
    default = {
      name       = "Default"
      vlan       = null # untagged native LAN; the container's vlan = 1 is commented out for this reason
      subnet     = "10.10.0.1/23"
      dhcp_start = "10.10.1.0"
      dhcp_stop  = "10.10.1.254"
      zone       = "Internal"
    }
    entertainment = {
      name       = "Entertainment"
      vlan       = 2
      subnet     = "10.10.2.1/24"
      dhcp_start = "10.10.2.6"
      dhcp_stop  = "10.10.2.254"
      zone       = "Restricted"
    }
    guest = {
      name       = "Guest"
      vlan       = 3
      subnet     = "10.10.3.1/24"
      dhcp_start = "10.10.3.6"
      dhcp_stop  = "10.10.3.254"
      zone       = "Restricted"
    }
    crusted = {
      name       = "Crusted"
      vlan       = 4
      subnet     = "10.10.4.1/24"
      dhcp_start = "10.10.4.6"
      dhcp_stop  = "10.10.4.254"
      zone       = "Dmz"
    }
    dmz = {
      name              = "DMZ"
      vlan              = 5
      subnet            = "10.10.5.1/24"
      dhcp_start        = "10.10.5.6"
      dhcp_stop         = "10.10.5.254"
      zone              = "Dmz"
      ipv6_pd_interface = "wan2" # only network with IPv6 (prefix delegation from the second WAN)
    }
  }
}

resource "unifi_network" "this" {
  for_each = local.networks

  name             = each.value.name
  vlan             = each.value.vlan
  subnet           = each.value.subnet
  firewall_zone_id = unifi_firewall_zone.this[each.value.zone].id

  auto_scale         = false
  setting_preference = "manual"

  ipv6_interface_type = try(each.value.ipv6_pd_interface, null) != null ? "pd" : "none"
  ipv6_pd_interface   = try(each.value.ipv6_pd_interface, null)

  dhcp_server = {
    enabled           = true
    start             = each.value.dhcp_start
    stop              = each.value.dhcp_stop
    conflict_checking = true
  }
}
