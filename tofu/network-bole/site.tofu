# Bole: the main site (Proxmox cluster, DMZ, DNS). Shared names/VLANs/zones,
# SSIDs, generic firewall policies and settings live in modules/unifi_site;
# everything here is Bole-specific.
#
# Subnets/gateways match the network_testing_* containers in core/main.tofu,
# which probe the isolation between these VLANs.
module "site" {
  source = "../modules/unifi_site"

  networks = {
    default       = { subnet = "10.10.0.1/23", dhcp_start = "10.10.1.0", dhcp_stop = "10.10.1.254" }
    entertainment = { subnet = "10.10.2.1/24", dhcp_start = "10.10.2.6", dhcp_stop = "10.10.2.254" }
    guest         = { subnet = "10.10.3.1/24", dhcp_start = "10.10.3.6", dhcp_stop = "10.10.3.254" }
    crusted       = { subnet = "10.10.4.1/24", dhcp_start = "10.10.4.6", dhcp_stop = "10.10.4.254" }
    dmz = {
      subnet            = "10.10.5.1/24"
      dhcp_start        = "10.10.5.6"
      dhcp_stop         = "10.10.5.254"
      ipv6_pd_interface = "wan" # only network with IPv6 (prefix delegation from the 10gb WAN1)
    }
  }

  wlan_passphrases = var.unifi_wlan_passphrases

  # Inherited from the Salon backup; Salon still sits behind the Wingo router.
  upstream_lan = { name = "Wingo", cidr = "192.168.0.0/16" }

  clients = {
    # --- Default (10.10.0.0/23) ---
    netgear_switch = { mac = "54:07:7d:1d:fa:d1", name = "Netgear GS108Ev4", fixed_ip = "10.10.0.99", dns = "netgear.nico" }
    proxmox1       = { mac = "74:56:3c:e6:6c:bd", fixed_ip = "10.10.0.100", dns = "proxmox.nico" }
    proxmox2       = { mac = "98:fa:9b:82:61:fb", name = "proxmox2", fixed_ip = "10.10.0.101", dns = "node2.nico" }
    proxmox3       = { mac = "f8:75:a4:9b:85:fa", name = "proxmox3", fixed_ip = "10.10.0.103", dns = "node3.nico" }
    pbs            = { mac = "98:fa:9b:82:6a:43", name = "pbs", fixed_ip = "10.10.0.105", dns = "pbs.nico" }
    minix          = { mac = "a0:1e:0b:14:af:39", fixed_ip = "10.10.0.201", dns = "minix.nico" }
    synology_nic2  = { mac = "90:09:d0:56:92:12", fixed_ip = "10.10.0.251", dns = "nas-2.nico" } # Garage S3 (tofu state backend)
    synology_nic1  = { mac = "90:09:d0:56:92:11", fixed_ip = "10.10.0.252", dns = "nas-1.nico" }

    # --- Crusted (10.10.4.0/24) ---
    mystrom_main   = { mac = "b4:8a:0a:b5:33:00", name = "mystrom main", fixed_ip = "10.10.4.48" }
    mystrom_pc     = { mac = "08:3a:8d:94:3e:4c", name = "msytrom PC", fixed_ip = "10.10.4.54" }
    mystrom_server = { mac = "c8:f0:9e:be:12:10", name = "mystrom server", fixed_ip = "10.10.4.103" }
  }

  # Only these Salon devices may open connections in over the VPN.
  # Routes into the Site Magic tunnel (Site Magic doesn't install them itself).
  # peer_name is the tunnel entry's name here: Salon's gateway name when the
  # connection was made ("UDR7"), not its current one - update it if Site
  # Magic is ever re-created.
  site_to_site = { peer_name = "UDR7", remote_cidrs = ["10.20.0.0/16"] }

  vpn_lockdown = true
  vpn_inbound_allow = {
    salon_printer_to_nas = {
      name    = "Allow Salon Printer to NAS"
      src_ips = ["10.20.1.125"]                # Salon: brother_printer (scan to FTP)
      dst_ips = ["10.10.0.251", "10.10.0.252"] # synology_nic2, synology_nic1
      ports   = "21,55536-55899"               # FTP control + DSM's default passive data range
    }
    salon_dns = {
      name     = "Allow Salon DNS"
      src_ips  = ["10.20.0.0/16"]               # Salon's gateway forwards its clients' queries
      dst_ips  = ["10.10.0.245", "10.10.0.244"] # bootstrap: dns1, dns2
      protocol = "tcp_udp"
      ports    = "53"
    }
    salon_default_to_traefik = {
      name    = "Allow Salon Default to Traefik"
      src_ips = ["10.20.0.0/23"] # Salon's trusted Default network (not Guest/Entertainment/Crusted)
      dst_ips = ["10.10.0.250"]  # core: traefik_default - fronts all internal web UIs
      ports   = "80,443"
    }
    salon_tv_to_traefik = {
      name    = "Allow Salon TV to Traefik"
      src_ips = ["10.20.2.237"] # Salon: samsung_tv
      dst_ips = ["10.10.0.250"] # core: traefik_default
      ports   = "80,443"
    }
  }

  # Inbound into the DMZ on the 10gb uplink (WAN1). Targets are core/compute
  # containers, as literal IPs since this stack mustn't depend on their state.
  port_forward_wan_interface = "wan"
  port_forwards = {
    ssh_jumphost       = { name = "ssh-jumphost", wan_port = "2222", fwd_ip = "10.10.5.252", fwd_port = "22", logging = true }             # core: jumphost
    http_https_traefik = { name = "http-https-traefik", wan_port = "80,443", fwd_ip = "10.10.5.250", fwd_port = "80,443", logging = true } # core: traefik_dmz
    factorio           = { name = "factorio", wan_port = "34197,27015", fwd_ip = "10.10.5.248", fwd_port = "34197,27015" }                 # compute: game_server
    satisfactory       = { name = "satisfactory", wan_port = "7777", fwd_ip = "10.10.5.248", fwd_port = "7777" }                           # compute: game_server
  }
}
