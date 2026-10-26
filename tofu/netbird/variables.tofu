variable "netbird_management_url" {
  type    = string
  default = "https://netbird.courgettes.club"
}

variable "netbird_token" {
  type      = string
  sensitive = true
}

# Plaintext of the `netbird` client's secret in Authelia (whose config only
# holds its pbkdf2 digest, ansible vault: authelia_oidc_netbird_client_secret_digest).
variable "netbird_authelia_client_secret" {
  type      = string
  sensitive = true
}

# Not Tailscale's: both default to 100.64.0.0/10, and the two run side by
# side for a while. Changing it re-addresses every peer.
variable "network_range" {
  type    = string
  default = "100.120.0.0/16"
}

# Same subnets the vpn LXC advertises over Tailscale.
variable "home_subnets" {
  type = list(string)
  default = [
    "10.10.0.0/24",
    "10.10.1.0/24",
    "10.10.2.0/24",
    "10.10.3.0/24",
    "10.10.4.0/24",
    "10.10.5.0/24",
  ]
}

# The VPS's NetBird address, known once it's enrolled (dashboard, or
# `netbird status` on it). Until then there's no ldap.sso.courgettes.club
# record for Jellyfin.
variable "vps_mesh_ip" {
  type    = string
  default = "100.120.245.153"
}
