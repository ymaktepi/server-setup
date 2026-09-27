# Salon's uplinks, behind the ISP (Wingo) router. Only "10gb link" (WAN2) is
# in use; the 1gb WAN is kept disabled as a manual fallback.

resource "unifi_wan" "primary" {
  name         = "10gb link"
  networkgroup = "WAN2"
  enabled      = true

  # This (factory-reset) controller forces "auto" and ignores "manual" - the
  # manual DNS/IPv6 settings below are applied regardless.
  setting_preference      = "auto"
  ipv6_setting_preference = "manual"

  type    = "dhcp"
  type_v6 = "dhcpv6"

  dhcp = {
    cos = 0
  }
  dhcpv6 = {
    cos                 = 0
    pd_size             = 56
    pd_size_auto        = true
    wan_delegation_type = "pd"
  }

  # The gateway's own DNS stays public: its queries would reach Bole from the
  # tunnel address (192.168.2.1), which Bole doesn't allow. Clients get Bole's
  # Technitium servers via DHCP instead (site.tofu: dhcp_dns_servers).
  dns = {
    preference      = "manual"
    primary         = "1.1.1.1"
    secondary       = "8.8.8.8"
    ipv6_preference = "auto"
  }

  # Must stay weighted: the controller requires at least one weighted WAN
  # (api.err.MissingWeightedWanNetwork), and the fallback is failover-only.
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

resource "unifi_wan" "fallback" {
  name         = "fallback 1gb unplugged"
  networkgroup = "WAN"
  enabled      = false

  # This (factory-reset) controller forces "auto" and ignores "manual" - the
  # manual DNS/IPv6 settings below are applied regardless.
  setting_preference      = "auto"
  ipv6_setting_preference = "manual"

  type = "dhcp"

  dhcpv6 = {
    pd_size_auto        = false
    wan_delegation_type = "single_network"
  }
  # No single_network_lan: this controller drops it while the WAN's IPv6 is
  # disabled (and it's unplugged anyway).

  dns = {
    preference      = "manual"
    primary         = "1.1.1.1"
    secondary       = "1.0.0.1"
    ipv6_preference = "manual"
    ipv6_primary    = "2606:4700:4700::1111"
    ipv6_secondary  = "2606:4700:4700::1001"
  }

  load_balance = {
    type              = "failover-only"
    weight            = 99
    failover_priority = 2
  }

  provider_capabilities = {
    download_kilobits_per_second = 990000
    upload_kilobits_per_second   = 990000
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
