# Bole's uplinks. The 10gb fibre is on WAN1 (moved from WAN2); WAN2 has no
# port assigned. Both are in the built-in External firewall zone, which the
# controller assigns on its own.
#
# Resources are named after the WAN slot (networkgroup), not the role, since
# the slot is what's fixed per object.

resource "unifi_wan" "wan1" {
  # Renamed after wan2 has given up the "10gb link" name.
  depends_on = [unifi_wan.wan2]

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
    # Unused while ipv6_preference is auto; left over from this WAN's
    # fallback days and kept by the controller, so declared to match.
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

# No port assigned. Kept weighted (rather than failover-only/disabled) so the
# "at least one weighted WAN" rule holds while wan1 is being switched over.
resource "unifi_wan" "wan2" {
  name         = "WAN2 unassigned"
  networkgroup = "WAN2"
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
    wan_delegation_type = "pd"
  }

  dns = {
    preference      = "manual"
    primary         = "10.10.0.245"
    secondary       = "10.10.0.244"
    ipv6_preference = "auto"
  }

  # Priorities must be unique at every step (api.err.WanFailOverPriorityAlreadyExists);
  # 3 never collides with wan1's old (2) or new (1) value.
  load_balance = {
    type              = "weighted"
    weight            = 50
    failover_priority = 3
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
