resource "netbird_account_settings" "this" {
  network_range = var.network_range

  # lldap groups (Authelia's `groups` claim) become NetBird groups at each
  # login, and are propagated to the user's peers.
  jwt_groups_enabled         = true
  jwt_groups_claim_name      = "groups"
  groups_propagation_enabled = true
}

# Authelia as an OIDC connector of the embedded IdP. The owner's local login
# stays available, as the way in when Authelia is down.
#
# `pocketid`, not `oidc`: it's the same generic OIDC connector, except that it
# also asks for the `groups` scope (`oidc` never does, and nothing else can
# add it). The type can't change in place, and a new connector means new
# NetBird users: everyone logging in through Authelia starts over.
resource "netbird_identity_provider" "authelia" {
  name          = "Authelia"
  type          = "pocketid"
  client_id     = "netbird"
  client_secret = var.netbird_authelia_client_secret
  issuer        = "https://sso.courgettes.club"
}

#region groups
# Full access: the lldap group of the same name, created by NetBird at the
# first login of one of its members. Not a resource: NetBird only syncs users
# into groups it created from the claim itself, never into one made through
# the API, even with the same name. So it must exist before a full apply
# (`make netbird-apply-idp`, then log in, see the README).
data "netbird_group" "admins" {
  name = "netbird_admins"
}

# Infra peers, enrolled by ansible (install_netbird_client) with the setup
# keys below, which put them in their group.
resource "netbird_group" "vps" {
  name = "vps"
}

resource "netbird_group" "home_router" {
  name = "home-router"
}

resource "netbird_group" "jellyfin" {
  name = "jellyfin"
}

resource "netbird_group" "home_lan" {
  name = "home-lan"
}
#endregion

#region setup keys
locals {
  infra_peers = {
    vps         = netbird_group.vps.id
    home_router = netbird_group.home_router.id
    jellyfin    = netbird_group.jellyfin.id
  }
}

# One-off: once used, re-running ansible doesn't need it (it only enrols a
# peer that isn't connected yet). A re-installed peer needs a new one: taint it.
resource "netbird_setup_key" "infra" {
  for_each = local.infra_peers

  name           = each.key
  type           = "one-off"
  expiry_seconds = 7 * 24 * 3600
  auto_groups    = [each.value]
  ephemeral      = false
}
#endregion

#region home network
resource "netbird_network" "home" {
  name        = "home"
  description = "Bole's VLANs, routed by the vpn LXC"
}

resource "netbird_network_resource" "home" {
  for_each = toset(var.home_subnets)

  network_id = netbird_network.home.id
  name       = each.value
  address    = each.value
  groups     = [netbird_group.home_lan.id]
  enabled    = true
}

resource "netbird_network_router" "home" {
  network_id  = netbird_network.home.id
  peer_groups = [netbird_group.home_router.id]
  # home hosts see the router's LAN address, no return route needed
  masquerade = true
  metric     = 9999
  enabled    = true
}
#endregion

#region exit nodes
# skip_auto_apply: picked per device, never forced on.
resource "netbird_route" "exit_vps" {
  network_id      = "exit-vps"
  description     = "Exit through the VPS"
  network         = "0.0.0.0/0"
  peer_groups     = [netbird_group.vps.id]
  groups          = [data.netbird_group.admins.id]
  masquerade      = true
  skip_auto_apply = true
  enabled         = true
}

resource "netbird_route" "exit_home" {
  network_id      = "exit-home"
  description     = "Exit through home (vpn LXC)"
  network         = "0.0.0.0/0"
  peer_groups     = [netbird_group.home_router.id]
  groups          = [data.netbird_group.admins.id]
  masquerade      = true
  skip_auto_apply = true
  enabled         = true
}
#endregion

#region policies
# NetBird's default "All" policy (everyone to everyone) isn't managed here:
# delete it in the dashboard once these exist.
resource "netbird_policy" "admins" {
  name    = "admins"
  enabled = true

  rule {
    name          = "admins to everything"
    action        = "accept"
    bidirectional = false
    enabled       = true
    protocol      = "all"
    sources       = [data.netbird_group.admins.id]
    destinations = [
      data.netbird_group.admins.id,
      netbird_group.vps.id,
      netbird_group.home_router.id,
      netbird_group.jellyfin.id,
      netbird_group.home_lan.id,
    ]
  }
}

resource "netbird_policy" "jellyfin_ldap" {
  name    = "jellyfin-ldap"
  enabled = true

  rule {
    name          = "jellyfin to lldap (LDAPS)"
    action        = "accept"
    bidirectional = false
    enabled       = true
    protocol      = "tcp"
    ports         = ["636"]
    sources       = [netbird_group.jellyfin.id]
    destinations  = [netbird_group.vps.id]
  }
}
#endregion

#region dns
# Split DNS for the home zones: the zones and servers (dns1 first) of
# bootstrap's Technitium, reached through the home network's router. Not
# primary: everything else stays on each device's own DNS, which keeps working
# when home is down.
resource "netbird_nameserver_group" "home" {
  name        = "home"
  description = "Technitium (dns1, dns2) for the home zones"
  nameservers = [
    for ip in data.terraform_remote_state.bootstrap.outputs.dns.servers :
    { ip = ip, ns_type = "udp", port = 53 }
  ]
  domains                = data.terraform_remote_state.bootstrap.outputs.dns.zones
  primary                = false
  search_domains_enabled = false
  groups                 = [data.netbird_group.admins.id]
  enabled                = true
}

# Jellyfin's LDAP server name, resolved to the VPS's mesh address for the
# jellyfin peer only (publicly it's the VPS's public IP, where 636 is closed
# to anything outside the mesh).
resource "netbird_dns_zone" "ldap" {
  count = var.vps_mesh_ip == null ? 0 : 1

  name                = "ldap"
  domain              = "ldap.sso.courgettes.club"
  enabled             = true
  distribution_groups = [netbird_group.jellyfin.id]
}

resource "netbird_dns_record" "ldap" {
  count = var.vps_mesh_ip == null ? 0 : 1

  zone_id = netbird_dns_zone.ldap[0].id
  name    = "ldap.sso.courgettes.club"
  type    = "A"
  content = var.vps_mesh_ip
  ttl     = 300
}

# lldap's web UI, for the admins: like LDAPS, it only accepts mesh addresses,
# and publicly the name is the VPS's public IP.
resource "netbird_dns_zone" "lldap" {
  count = var.vps_mesh_ip == null ? 0 : 1

  name                = "lldap"
  domain              = "lldap.sso.courgettes.club"
  enabled             = true
  distribution_groups = [data.netbird_group.admins.id]
}

resource "netbird_dns_record" "lldap" {
  count = var.vps_mesh_ip == null ? 0 : 1

  zone_id = netbird_dns_zone.lldap[0].id
  name    = "lldap.sso.courgettes.club"
  type    = "A"
  content = var.vps_mesh_ip
  ttl     = 300
}
#endregion
