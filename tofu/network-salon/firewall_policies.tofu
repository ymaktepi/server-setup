# Salon-specific firewall policies. The shared ones (and the VPN lockdown)
# are in modules/unifi_site.

locals {
  zone_ids = module.site.zone_ids
}

# The TV (Entertainment, Restricted zone) uses Bole's traefik_default over
# the site-to-site VPN. Restricted -> Vpn is blocked by the controller's
# defaults, so it needs this outbound allow; Bole's matching inbound allow is
# in network-bole/site.tofu.
resource "unifi_firewall_policy" "tv_to_traefik_default" {
  name                 = "tv"
  action               = "ALLOW"
  protocol             = "tcp"
  create_allow_respond = true

  source = {
    zone_id         = local.zone_ids["Restricted"]
    matching_target = "CLIENT"
    client_macs     = ["84:c0:ef:c0:5b:42"]
  }
  destination = {
    zone_id            = local.zone_ids["Vpn"]
    matching_target    = "IP"
    ips                = ["10.10.0.250"] # Bole: traefik_default
    port_matching_type = "SPECIFIC"
    port               = "80,443"
  }
}

# DNS to Bole's Technitium servers (handed out by DHCP) over the tunnel.
# Restricted/Dmz -> Vpn is blocked by the controller's defaults; Internal is
# allowed already.
resource "unifi_firewall_policy" "dns_to_bole" {
  for_each = toset(["Restricted", "Dmz"])

  name                 = "Allow DNS to Bole"
  action               = "ALLOW"
  protocol             = "tcp_udp"
  create_allow_respond = true

  source = {
    zone_id         = local.zone_ids[each.value]
    matching_target = "ANY"
  }
  destination = {
    zone_id            = local.zone_ids["Vpn"]
    matching_target    = "IP"
    ips                = ["10.10.0.245", "10.10.0.244"] # Bole: dns1, dns2
    port_matching_type = "SPECIFIC"
    port               = "53"
  }
}
