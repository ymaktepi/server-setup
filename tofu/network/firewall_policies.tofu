# User-defined zone-based firewall policies. The controller's ~95 predefined
# policies (built-in zone defaults) are left to the controller.
#
# Ordering within a zone pair can't be managed through the provider (index is
# read-only, new policies are appended) - reorder in the UniFi UI if needed.
#
# Literal IPs name their core-stack container in a comment; this stack mustn't
# depend on core's state.

locals {
  zone_ids = { for name, z in unifi_firewall_zone.this : name => z.id }

  # The ISP (Wingo) router's LAN sits upstream of the gateway's WAN.
  wingo_network = "192.168.0.0/16"
}

# --- Internal ---------------------------------------------------------------

resource "unifi_firewall_policy" "internal_to_restricted_allow_all" {
  name                 = "Allow All Traffic"
  action               = "ALLOW"
  ip_version           = "BOTH"
  create_allow_respond = true

  source = {
    zone_id         = local.zone_ids["Internal"]
    matching_target = "ANY"
  }
  destination = {
    zone_id         = local.zone_ids["Restricted"]
    matching_target = "ANY"
  }
}

# --- Restricted (Entertainment, Guest) --------------------------------------

resource "unifi_firewall_policy" "restricted_allow_all" {
  name                 = "Allow All Traffic"
  action               = "ALLOW"
  ip_version           = "BOTH"
  create_allow_respond = true

  source = {
    zone_id         = local.zone_ids["Restricted"]
    matching_target = "ANY"
  }
  destination = {
    zone_id         = local.zone_ids["Restricted"]
    matching_target = "ANY"
  }
}

resource "unifi_firewall_policy" "restricted_to_internal_return" {
  name                  = "Allow Return Traffic"
  action                = "ALLOW"
  ip_version            = "BOTH"
  connection_state_type = "RESPOND_ONLY"

  source = {
    zone_id         = local.zone_ids["Restricted"]
    matching_target = "ANY"
  }
  destination = {
    zone_id         = local.zone_ids["Internal"]
    matching_target = "ANY"
  }
}

resource "unifi_firewall_policy" "restricted_to_gateway_return" {
  name                  = "Allow Return Traffic"
  action                = "ALLOW"
  ip_version            = "BOTH"
  connection_state_type = "RESPOND_ONLY"

  source = {
    zone_id         = local.zone_ids["Restricted"]
    matching_target = "ANY"
  }
  destination = {
    zone_id         = local.zone_ids["Gateway"]
    matching_target = "ANY"
  }
}

resource "unifi_firewall_policy" "restricted_block_unifi_management" {
  name       = "Block Unifi Management"
  action     = "BLOCK"
  ip_version = "BOTH"

  source = {
    zone_id         = local.zone_ids["Restricted"]
    matching_target = "ANY"
  }
  destination = {
    zone_id            = local.zone_ids["Gateway"]
    matching_target    = "ANY"
    port_matching_type = "OBJECT"
    port_group_id      = unifi_firewall_group.this["http_https_ssh_unifihttps"].id
  }
}

resource "unifi_firewall_policy" "restricted_block_wingo_router" {
  name       = "Block Wingo Router"
  action     = "BLOCK"
  ip_version = "BOTH"

  source = {
    zone_id         = local.zone_ids["Restricted"]
    matching_target = "ANY"
  }
  destination = {
    zone_id         = local.zone_ids["Gateway"]
    matching_target = "IP"
    ips             = [local.wingo_network]
  }
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

# --- Dmz (Crusted, DMZ) -----------------------------------------------------

resource "unifi_firewall_policy" "dmz_block_wingo_network" {
  name       = "Block Wingo Network"
  action     = "BLOCK"
  ip_version = "BOTH"

  source = {
    zone_id         = local.zone_ids["Dmz"]
    matching_target = "ANY"
  }
  destination = {
    zone_id         = local.zone_ids["Gateway"]
    matching_target = "IP"
    ips             = [local.wingo_network]
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
