# Inbound port forwards on the 10gb uplink (wan2) into the DMZ. Targets are
# containers from the core/compute stacks, written as literal IPs (named in
# the comments) since this stack mustn't depend on their state.
locals {
  port_forwards = {
    ssh_jumphost = {
      name     = "ssh-jumphost"
      wan_port = "2222"
      fwd_ip   = "10.10.5.252" # core: jumphost
      fwd_port = "22"
      logging  = true
    }
    http_https_traefik = {
      name     = "http-https-traefik"
      wan_port = "80,443"
      fwd_ip   = "10.10.5.250" # core: traefik_dmz
      fwd_port = "80,443"
      logging  = true
    }
    factorio = {
      name     = "factorio"
      wan_port = "34197,27015"
      fwd_ip   = "10.10.5.248" # compute: game_server
      fwd_port = "34197,27015"
      logging  = false
    }
    satisfactory = {
      name     = "satisfactory"
      wan_port = "7777"
      fwd_ip   = "10.10.5.248" # compute: game_server
      fwd_port = "7777"
      logging  = false
    }
  }
}

resource "unifi_port_forward" "this" {
  for_each = local.port_forwards

  name     = each.value.name
  protocol = "tcp_udp"
  logging  = each.value.logging

  wan = {
    interface  = "wan2"
    ip_address = "any"
    port       = each.value.wan_port
  }

  forward = {
    ip   = each.value.fwd_ip
    port = each.value.fwd_port
  }
}
