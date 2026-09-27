# Zone-based firewall zones. Every zone on the controller is listed, including
# the built-in ones, so this file is the full picture.
#
# Membership is set from the zone side (network_ids), and only for the zones
# networks get moved into. The provider sends network_ids as a complete list
# whenever a zone is updated - an unset list would empty the zone - so it's
# only set where we own the full membership. Internal (Default, where new
# networks land) and External (the WANs) are left to the controller.
locals {
  firewall_zones = toset([
    "Internal",
    "External",
    "Gateway",
    "Vpn",
    "Hotspot",
    "Dmz",
    "Restricted",
  ])

  membership_zones = toset(["Restricted", "Dmz"])

  zone_ids = { for name, z in unifi_firewall_zone.this : name => z.id }
}

resource "unifi_firewall_zone" "this" {
  for_each = local.firewall_zones

  name = each.value
  network_ids = (
    contains(local.membership_zones, each.value)
    ? [for k, n in local.networks : unifi_network.this[k].id if n.zone == each.value]
    : null
  )
}
