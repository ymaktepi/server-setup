# Shared across sites: names, VLAN IDs and firewall zones. Addressing is
# per-site (var.networks), which also selects the networks a site has.
locals {
  network_catalogue = {
    default       = { name = "Default", vlan = null, zone = "Internal" } # untagged native LAN
    entertainment = { name = "Entertainment", vlan = 2, zone = "Restricted" }
    guest         = { name = "Guest", vlan = 3, zone = "Restricted" }
    crusted       = { name = "Crusted", vlan = 4, zone = "Dmz" }
    dmz           = { name = "DMZ", vlan = 5, zone = "Dmz" }
  }

  networks = { for k, n in var.networks : k => merge(local.network_catalogue[k], n) }
}

resource "unifi_network" "this" {
  for_each = local.networks

  # Zone membership is set on the zone (zones.tofu), not here: controllers
  # set up fresh ignore firewall_zone_id on network create/update and keep new
  # networks in Internal. Left unset, the provider doesn't send it at all.
  name   = each.value.name
  vlan   = each.value.vlan
  subnet = each.value.subnet

  auto_scale         = false
  setting_preference = "manual"

  ipv6_interface_type = each.value.ipv6_pd_interface != null ? "pd" : "none"
  ipv6_pd_interface   = each.value.ipv6_pd_interface

  dhcp_server = {
    enabled           = true
    start             = each.value.dhcp_start
    stop              = each.value.dhcp_stop
    conflict_checking = true
    dns_enabled       = var.dhcp_dns_servers != null
    dns_servers       = var.dhcp_dns_servers
  }
}
