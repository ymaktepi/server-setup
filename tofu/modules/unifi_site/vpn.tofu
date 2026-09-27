# Lockdown of traffic arriving over the site-to-site VPN (var.vpn_lockdown).
#
# ORDERING: the provider can't set a policy's position - the controller
# appends each new policy to the end of its zone pair, and the first match
# wins. So the blocks must always be the newest policies: they depend on
# everything that has to precede them, and are re-created (replace_triggered_by)
# whenever an allow is added or changed, which puts them back behind it.

resource "unifi_firewall_policy" "vpn_allow" {
  for_each = var.vpn_inbound_allow

  name                 = each.value.name
  action               = "ALLOW"
  protocol             = each.value.protocol
  create_allow_respond = true

  source = {
    zone_id         = local.zone_ids["Vpn"]
    matching_target = "IP"
    ips             = each.value.src_ips
  }
  destination = {
    zone_id            = local.zone_ids[each.value.zone]
    matching_target    = "IP"
    ips                = each.value.dst_ips
    port_matching_type = "SPECIFIC"
    port               = each.value.ports
  }
}

# Replies to connections this site's Internal network opened towards the
# other site (Internal -> Vpn is allowed by the controller's defaults).
resource "unifi_firewall_policy" "vpn_to_internal_return" {
  count = var.vpn_lockdown ? 1 : 0

  name                  = "Allow VPN Return Traffic"
  action                = "ALLOW"
  ip_version            = "BOTH"
  connection_state_type = "RESPOND_ONLY"

  source = {
    zone_id         = local.zone_ids["Vpn"]
    matching_target = "ANY"
  }
  destination = {
    zone_id         = local.zone_ids["Internal"]
    matching_target = "ANY"
  }
}

resource "unifi_firewall_policy" "vpn_block" {
  for_each = var.vpn_lockdown ? toset(["Internal", "Dmz", "Gateway", "Hotspot"]) : toset([])

  depends_on = [
    unifi_firewall_policy.vpn_allow,
    unifi_firewall_policy.vpn_to_internal_return,
  ]

  lifecycle {
    replace_triggered_by = [unifi_firewall_policy.vpn_allow]
  }

  name       = "Block VPN Traffic"
  action     = "BLOCK"
  ip_version = "BOTH"

  source = {
    zone_id         = local.zone_ids["Vpn"]
    matching_target = "ANY"
  }
  destination = {
    zone_id         = local.zone_ids[each.value]
    matching_target = "ANY"
  }
}
