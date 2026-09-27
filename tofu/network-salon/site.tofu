# Salon: no custom infra (no DMZ, no inbound port forwards, no local DNS).
# Addressed 10.20.x (Bole is 10.10.x) - same VLAN IDs and network names, but
# the ranges must not overlap for the two sites to route to each other.
module "site" {
  source = "../modules/unifi_site"

  networks = {
    default       = { subnet = "10.20.0.1/23", dhcp_start = "10.20.1.0", dhcp_stop = "10.20.1.254" }
    entertainment = { subnet = "10.20.2.1/24", dhcp_start = "10.20.2.6", dhcp_stop = "10.20.2.254" }
    guest         = { subnet = "10.20.3.1/24", dhcp_start = "10.20.3.6", dhcp_stop = "10.20.3.254" }
    crusted       = { subnet = "10.20.4.1/24", dhcp_start = "10.20.4.6", dhcp_stop = "10.20.4.254" }
  }

  wlan_passphrases = var.unifi_wlan_passphrases

  # Bole's Technitium servers over the site-to-site tunnel, handed straight to
  # clients (their 10.20.x sources are allowed in by Bole's "Allow Salon DNS";
  # Restricted/Dmz need the outbound allows in firewall_policies.tofu). The
  # gateway itself keeps public DNS (wan.tofu). If the tunnel is down, Salon's
  # clients have no DNS.
  dhcp_dns_servers = ["10.10.0.245", "10.10.0.244"] # bootstrap: dns1, dns2

  # Salon sits behind the Wingo router; its WAN is on that router's LAN.
  upstream_lan = { name = "Wingo", cidr = "192.168.0.0/24" }

  clients = {
    nico_pi    = { mac = "2c:cf:67:30:48:c5", name = "nico-pi", fixed_ip = "10.20.0.11", dns = "pi.nico" } # Home Assistant
    sarah_nas  = { mac = "00:11:32:3d:1f:48", name = "sarah-nas", fixed_ip = "10.20.0.200", dns = "nas.sarah" }
    prusa_mini = { mac = "08:3a:8d:ce:16:db", fixed_ip = "10.20.3.195", dns = "prusa.nico" }

    # Fixed so Bole's VPN rules can match them (network-bole/site.tofu).
    brother_printer = { mac = "f0:a6:54:88:db:a9", name = "Brother Printer", fixed_ip = "10.20.1.125" } # scans to Bole's NAS
    samsung_tv      = { mac = "84:c0:ef:c0:5b:42", fixed_ip = "10.20.2.237" }                           # Entertainment
  }

  # Routes into the Site Magic tunnel (Site Magic doesn't install them itself).
  # peer_name is the tunnel entry's name here (Bole's gateway name when the
  # connection was made) - update it if Site Magic is ever re-created.
  site_to_site = { peer_name = "Bole-Router", remote_cidrs = ["10.10.0.0/16"] }

  # Only Bole's traefik_default may open connections in over the VPN (to Home
  # Assistant). Salon -> Bole is governed by Bole's allows plus the outbound
  # rules in firewall_policies.tofu.
  vpn_lockdown = true
  vpn_inbound_allow = {
    bole_traefik_to_ha = {
      name    = "Allow Bole Traefik to Home Assistant"
      src_ips = ["10.10.0.250"] # Bole: traefik_default
      dst_ips = ["10.20.0.11"]  # nico_pi
      ports   = "8123"
    }
  }
}
