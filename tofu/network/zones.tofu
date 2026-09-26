# Zone-based firewall zones. Every zone on the controller is listed, including
# the built-in ones, so this file is the full picture. Keys are the zone names,
# which the import blocks in imports.tofu look zones up by.
#
# Membership is set from the network side (unifi_network.firewall_zone_id in
# networks.tofu), so network_ids is deliberately left unset here - setting it
# on both sides makes the two fight.
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
}

resource "unifi_firewall_zone" "this" {
  for_each = local.firewall_zones

  name = each.value
}
