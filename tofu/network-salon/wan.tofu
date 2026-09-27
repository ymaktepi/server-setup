# Salon's uplinks, behind the ISP (Wingo) router. Only "10gb link" (WAN2) is
# in use; the 1gb WAN is kept disabled as a manual fallback.

resource "unifi_wan" "primary" {
  name         = "10gb link"
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
    pd_size             = 56
    pd_size_auto        = true
    wan_delegation_type = "pd"
  }

  # Bole's Technitium servers (dns1 .245, dns2 .244) over the site-to-site
  # VPN, so Salon resolves the same internal names (*.local.courgettes.club,
  # *.nico, ...). Salon's clients keep using their local gateway as resolver.
  # Trade-off: if the tunnel is down, Salon has no DNS at all. Deliberately no
  # public fallback here - mixing resolvers that disagree about internal names
  # gets NXDOMAINs cached. Allowed in by Bole's vpn_inbound_allow.
  dns = {
    preference      = "manual"
    primary         = "10.10.0.245"
    secondary       = "10.10.0.244"
    ipv6_preference = "auto"
  }

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

  setting_preference      = "manual"
  ipv6_setting_preference = "manual"

  type = "dhcp"

  dhcpv6 = {
    pd_size_auto        = false
    wan_delegation_type = "single_network"
  }
  single_network_lan = module.site.network_ids["default"]

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
