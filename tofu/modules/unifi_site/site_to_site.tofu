# Site Magic connects the tunnel but, on these controllers, never programs
# routes for the remote subnets (the remote_site_vpn_network ipset stays
# empty and LAN traffic to the other site leaves via the WAN). These static
# routes point the other site's range into the tunnel explicitly; firewalling
# is unchanged (traffic still arrives in the Vpn zone - see vpn.tofu).
#
# The tunnel's network entry is looked up by name, so re-creating the Site
# Magic connection (new ID) doesn't break this.
data "unifi_network" "site_to_site" {
  count = var.site_to_site == null ? 0 : 1

  name = var.site_to_site.peer_name
}

resource "unifi_static_route" "site_to_site" {
  for_each = var.site_to_site == null ? toset([]) : toset(var.site_to_site.remote_cidrs)

  name      = "Site Magic: ${var.site_to_site.peer_name} ${each.value}"
  type      = "interface-route"
  network   = each.value
  interface = data.unifi_network.site_to_site[0].id
  distance  = 1
}
