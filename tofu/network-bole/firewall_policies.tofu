# Bole-specific firewall policies (they point at particular hosts). The
# shared ones are in modules/unifi_site.
#
# Literal IPs name their core-stack container in a comment; this stack mustn't
# depend on core's state.

locals {
  zone_ids = module.site.zone_ids
}

# The DMZ Traefik serves status.courgettes.club from Uptime Kuma. Only that
# container: traefik_default would give it every internal UI by Host header.
resource "unifi_firewall_policy" "dmz_allow_traefik_forward" {
  name                 = "Allow Traefik Forward"
  description          = "status website (Uptime Kuma only)"
  action               = "ALLOW"
  protocol             = "tcp"
  create_allow_respond = true

  source = {
    zone_id         = local.zone_ids["Dmz"]
    matching_target = "IP"
    ips             = ["10.10.5.250"] # core: traefik_dmz
  }
  destination = {
    zone_id            = local.zone_ids["Internal"]
    matching_target    = "IP"
    ips                = ["10.10.0.253"] # core: uptime_kuma (nginx)
    port_matching_type = "SPECIFIC"
    port               = "443"
  }
}
