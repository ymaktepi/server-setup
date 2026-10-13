# Lockdown of traffic arriving over the site-to-site VPN (var.vpn_lockdown).
#
# ORDERING: the provider can't set a policy's position - the controller
# appends each new policy to the end of its zone pair, and the first match
# wins. So the blocks must always be the newest policies: they depend on
# everything that has to precede them, and are re-created (replace_triggered_by)
# whenever an allow or return rule is added or changed, which puts them back
# behind it.

resource "unifi_firewall_policy" "vpn_allow" {
  for_each = var.vpn_inbound_allow

  name     = each.value.name
  action   = "ALLOW"
  protocol = each.value.protocol
  # The controller refuses a respond rule towards the gateway itself
  # (FirewallPolicyCreateRespondTrafficPolicyNotAllowed); Gateway -> Vpn is
  # allowed by its defaults anyway.
  create_allow_respond = each.value.zone != "Gateway"

  source = {
    zone_id         = local.zone_ids["Vpn"]
    matching_target = "IP"
    ips             = each.value.src_ips
  }
  destination = {
    zone_id            = local.zone_ids[each.value.zone]
    matching_target    = each.value.dst_ips == null ? "ANY" : "IP"
    ips                = each.value.dst_ips
    port_matching_type = each.value.ports == null ? "ANY" : "SPECIFIC"
    port               = each.value.ports
  }
}

locals {
  vpn_blocked_zones = var.vpn_lockdown ? toset(["Internal", "Dmz", "Gateway", "Hotspot"]) : toset([])
}

# Replies to connections this site opened towards the other site, for every
# zone the lockdown blocks. Needed explicitly: the controller's own respond
# rules (create_allow_respond, and the ones it generates for outbound allows
# like "Allow DNS to Bole") get positions after all user policies, i.e. after
# vpn_block - without these, e.g. DNS replies to Crusted (Dmz zone) are
# dropped.
resource "unifi_firewall_policy" "vpn_return" {
  for_each = local.vpn_blocked_zones

  name                  = "Allow VPN Return Traffic"
  action                = "ALLOW"
  ip_version            = "BOTH"
  connection_state_type = "RESPOND_ONLY"

  source = {
    zone_id         = local.zone_ids["Vpn"]
    matching_target = "ANY"
  }
  destination = {
    zone_id         = local.zone_ids[each.value]
    matching_target = "ANY"
  }
}

moved {
  from = unifi_firewall_policy.vpn_to_internal_return[0]
  to   = unifi_firewall_policy.vpn_return["Internal"]
}

resource "unifi_firewall_policy" "vpn_block" {
  for_each = local.vpn_blocked_zones

  depends_on = [
    unifi_firewall_policy.vpn_allow,
    unifi_firewall_policy.vpn_return,
  ]

  lifecycle {
    replace_triggered_by = [
      unifi_firewall_policy.vpn_allow,
      unifi_firewall_policy.vpn_return,
    ]
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
