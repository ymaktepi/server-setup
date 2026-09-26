# Existing UniFi config is adopted with import blocks rather than recreated.
# Iterate until `make network-plan` shows no changes, then these can stay
# (they're no-ops once the resource is in state).
import {
  for_each = local.networks
  to       = unifi_network.this[each.key]
  id       = "name=${each.value.name}"
}

import {
  for_each = local.firewall_zones
  to       = unifi_firewall_zone.this[each.key]
  id       = "name=${each.value}"
}

# unifi_wan imports by name (no "name=" prefix, unlike networks/zones).
import {
  to = unifi_wan.primary
  id = "10gb link"
}

import {
  to = unifi_wan.fallback
  id = "fallback 1gb unplugged"
}
