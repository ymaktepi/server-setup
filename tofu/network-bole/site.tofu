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
      ipv6_pd_interface = "wan2" # only network with IPv6 (prefix delegation from the 10gb WAN)
    }
  }

  wlan_passphrases = var.unifi_wlan_passphrases

  # Inherited from the Salon backup; Salon still sits behind the Wingo router.
  upstream_lan = { name = "Wingo", cidr = "192.168.0.0/16" }

  clients = {
    # --- Default (10.10.0.0/23) ---
    netgear_switch = { mac = "54:07:7d:1d:fa:d1", name = "Netgear GS108Ev4", fixed_ip = "10.10.0.99", dns = "netgear.nico" }
    nico_pi        = { mac = "2c:cf:67:30:48:c5", name = "nico-pi", fixed_ip = "10.10.0.11", dns = "pi.nico" }
    proxmox1       = { mac = "74:56:3c:e6:6c:bd", fixed_ip = "10.10.0.100", dns = "proxmox.nico" }
    proxmox2       = { mac = "98:fa:9b:82:61:fb", name = "proxmox2", fixed_ip = "10.10.0.101", dns = "node2.nico" }
    proxmox3       = { mac = "f8:75:a4:9b:85:fa", name = "proxmox3", fixed_ip = "10.10.0.103", dns = "node3.nico" }
    pbs            = { mac = "98:fa:9b:82:6a:43", name = "pbs", fixed_ip = "10.10.0.105", dns = "pbs.nico" }
    sarah_nas      = { mac = "00:11:32:3d:1f:48", name = "sarah-nas", fixed_ip = "10.10.0.200", dns = "nas.sarah" }
    minix          = { mac = "a0:1e:0b:14:af:39", fixed_ip = "10.10.0.201", dns = "minix.nico" }
    synology_nic2  = { mac = "90:09:d0:56:92:12", fixed_ip = "10.10.0.251", dns = "nas-2.nico" } # Garage S3 (tofu state backend)
    synology_nic1  = { mac = "90:09:d0:56:92:11", fixed_ip = "10.10.0.252", dns = "nas-1.nico" }

    # --- Guest (10.10.3.0/24) ---
    prusa_mini = { mac = "08:3a:8d:ce:16:db", fixed_ip = "10.10.3.195", dns = "prusa.nico" }

    # --- Crusted (10.10.4.0/24) ---
    mystrom_main   = { mac = "b4:8a:0a:b5:33:00", name = "mystrom main", fixed_ip = "10.10.4.48" }
    mystrom_pc     = { mac = "08:3a:8d:94:3e:4c", name = "msytrom PC", fixed_ip = "10.10.4.54" }
    mystrom_server = { mac = "c8:f0:9e:be:12:10", name = "mystrom server", fixed_ip = "10.10.4.103" }
  }

  # Inbound into the DMZ on the 10gb uplink. Targets are core/compute
  # containers, as literal IPs since this stack mustn't depend on their state.
  port_forward_wan_interface = "wan2"
  port_forwards = {
    ssh_jumphost       = { name = "ssh-jumphost", wan_port = "2222", fwd_ip = "10.10.5.252", fwd_port = "22", logging = true }             # core: jumphost
    http_https_traefik = { name = "http-https-traefik", wan_port = "80,443", fwd_ip = "10.10.5.250", fwd_port = "80,443", logging = true } # core: traefik_dmz
    factorio           = { name = "factorio", wan_port = "34197,27015", fwd_ip = "10.10.5.248", fwd_port = "34197,27015" }                 # compute: game_server
    satisfactory       = { name = "satisfactory", wan_port = "7777", fwd_ip = "10.10.5.248", fwd_port = "7777" }                           # compute: game_server
  }
}
