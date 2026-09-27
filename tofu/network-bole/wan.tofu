# Bole's uplinks. The 10gb fibre is on WAN1 (moved from WAN2); WAN2 has no
# port assigned. Both are in the built-in External firewall zone, which the
# controller assigns on its own.
#
# Resources are named after the WAN slot (networkgroup), not the role, since
# the slot is what's fixed per object; which port a slot uses is set in the UI.

resource "unifi_wan" "wan1" {
  name         = "10gb link"
  networkgroup = "WAN"
  enabled      = true

  setting_preference      = "manual"
  ipv6_setting_preference = "manual"

  type    = "dhcp"
  type_v6 = "dhcpv6"

  dhcp = {
    cos = 0
  }
  dhcpv6 = {
    cos                 = 0
    pd_size             = 48
    pd_size_auto        = false
    wan_delegation_type = "pd" # delegated prefix feeds the DMZ network's IPv6 (site.tofu)
  }

  # dns1 (.245) then dns2 (.244), the Technitium servers from bootstrap/.
  # Literal IPs rather than a cross-stack reference: this stack mustn't
  # depend on bootstrap's state.
  dns = {
    preference      = "manual"
    primary         = "10.10.0.245"
    secondary       = "10.10.0.244"
    ipv6_preference = "auto"
    # Unused while ipv6_preference is auto, but the controller keeps them, so
    # they're declared to match (otherwise every apply fails on them).
    ipv6_primary   = "2606:4700:4700::1111"
    ipv6_secondary = "2606:4700:4700::1001"
  }

  # Must stay weighted: the controller requires at least one weighted WAN
  # (api.err.MissingWeightedWanNetwork).
  load_balance = {
    type              = "weighted"
    weight            = 50
    failover_priority = 1
  }

  provider_capabilities = {
    download_kilobits_per_second = 10000000
    upload_kilobits_per_second   = 10000000
  }

  igmp_proxy = {
    downstream = "none"
    upstream   = false
  }
  vlan = {
    enabled = false
  }
  mac_override_enabled = false
  report_wan_event     = false
}

# No port assigned. Only the attributes that matter are managed. It must stay
# weighted (at least one weighted WAN), and failover priorities must be unique
# (api.err.WanFailOverPriorityAlreadyExists).
resource "unifi_wan" "wan2" {
  name         = "WAN2 unassigned"
  networkgroup = "WAN2"
  enabled      = true

  load_balance = {
    type              = "weighted"
    weight            = 50
    failover_priority = 3
  }
}
