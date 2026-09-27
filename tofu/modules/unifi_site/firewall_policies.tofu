# Firewall policies shared by every site. Site-specific ones (pointing at
# particular hosts) live in the site stacks, using this module's zone_ids.
# The controller's ~95 predefined policies are left to the controller.
#
# Ordering within a zone pair can't be managed through the provider (index is
# read-only, new policies are appended) - reorder in the UniFi UI if needed.

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

resource "unifi_firewall_policy" "restricted_block_upstream_router" {
  count = var.upstream_lan == null ? 0 : 1

  name       = "Block ${var.upstream_lan.name} Router"
  action     = "BLOCK"
  ip_version = "BOTH"

  source = {
    zone_id         = local.zone_ids["Restricted"]
    matching_target = "ANY"
  }
  destination = {
    zone_id         = local.zone_ids["Gateway"]
    matching_target = "IP"
    ips             = [var.upstream_lan.cidr]
  }
}

# --- Dmz (Crusted, DMZ) -----------------------------------------------------

resource "unifi_firewall_policy" "dmz_block_upstream_network" {
  count = var.upstream_lan == null ? 0 : 1

  name       = "Block ${var.upstream_lan.name} Network"
  action     = "BLOCK"
  ip_version = "BOTH"

  source = {
    zone_id         = local.zone_ids["Dmz"]
    matching_target = "ANY"
  }
  destination = {
    zone_id         = local.zone_ids["Gateway"]
    matching_target = "IP"
    ips             = [var.upstream_lan.cidr]
  }
}
