# Bole-specific firewall policies (they point at particular hosts). The
# shared ones are in modules/unifi_site.
#
# Literal IPs name their core-stack container in a comment; this stack mustn't
# depend on core's state.

locals {
  zone_ids = module.site.zone_ids
}

resource "unifi_firewall_policy" "tv_to_traefik_default" {
  name                 = "tv"
  action               = "ALLOW"
  ip_version           = "BOTH"
  create_allow_respond = true

  source = {
    zone_id         = local.zone_ids["Restricted"]
    matching_target = "CLIENT"
    client_macs     = ["84:c0:ef:c0:5b:42"]
  }
  destination = {
    zone_id         = local.zone_ids["Internal"]
    matching_target = "IP"
    ips             = ["10.10.0.250"] # core: traefik_default
  }
}

resource "unifi_firewall_policy" "dmz_allow_traefik_forward" {
  name                 = "Allow Traefik Forward"
  description          = "forward status website"
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
    ips                = ["10.10.0.250"] # core: traefik_default
    port_matching_type = "SPECIFIC"
    port               = "443"
  }
}
