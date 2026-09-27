resource "unifi_port_forward" "this" {
  for_each = var.port_forwards

  name     = each.value.name
  protocol = "tcp_udp"
  logging  = each.value.logging

  wan = {
    interface  = var.port_forward_wan_interface
    ip_address = "any"
    port       = each.value.wan_port
  }

  forward = {
    ip   = each.value.fwd_ip
    port = each.value.fwd_port
  }
}
