variable "networks" {
  description = <<-EOT
    Which of the shared networks (local.network_catalogue) exist at this site,
    keyed like the catalogue, with this site's addressing. Names, VLANs and
    zones come from the catalogue so they're identical across sites.
  EOT
  type = map(object({
    subnet            = string # gateway IP + prefix, e.g. "10.10.2.1/24"
    dhcp_start        = string
    dhcp_stop         = string
    ipv6_pd_interface = optional(string) # WAN to take a delegated prefix from; null = no IPv6
  }))

  validation {
    condition     = alltrue([for k in keys(var.networks) : contains(keys(local.network_catalogue), k)])
    error_message = "Every key in networks must exist in local.network_catalogue (default, entertainment, guest, crusted, dmz)."
  }
}

variable "wlan_passphrases" {
  description = "Keyed like local.wlan_catalogue. Only SSIDs whose network exists at this site are created."
  type        = map(string)
  sensitive   = true
}

variable "clients" {
  description = <<-EOT
    DHCP reservations: fixed IP plus optional display name and local DNS record.
    Removing an entry only drops it from tofu - the reservation stays on the
    controller. To really remove one, first apply it with
    forget_on_destroy = true, then delete the entry: the controller then
    forgets the device (reservation, name and history).
  EOT
  type = map(object({
    mac               = string
    fixed_ip          = string
    name              = optional(string)
    dns               = optional(string)
    forget_on_destroy = optional(bool, false)
  }))
  default = {}
}

variable "port_forwards" {
  type = map(object({
    name     = string
    wan_port = string
    fwd_ip   = string
    fwd_port = string
    logging  = optional(bool, false)
  }))
  default = {}
}

variable "port_forward_wan_interface" {
  description = "WAN the port forwards listen on (wan, wan2 or both)."
  type        = string
  default     = "wan"
}

variable "upstream_lan" {
  description = <<-EOT
    The ISP router's LAN when this gateway sits behind one (double NAT). The
    Restricted and Dmz zones are blocked from reaching it. null = none.
  EOT
  type = object({
    name = string # used in the policy names ("Block <name> Router/Network")
    cidr = string
  })
  default = null
}

variable "igmp_snooping_networks" {
  description = "Network keys IGMP snooping is enabled for (ones absent at this site are skipped)."
  type        = list(string)
  default     = ["entertainment", "guest", "crusted"]
}

variable "vpn_lockdown" {
  description = <<-EOT
    Block traffic arriving over site-to-site VPN into Internal, Dmz, Gateway
    and Hotspot, except var.vpn_inbound_allow and replies to connections this
    site opened. UniFi's default for the Vpn zone is to allow all of that.
  EOT
  type        = bool
  default     = false
}

variable "vpn_inbound_allow" {
  description = <<-EOT
    Flows the other site may open into this one (Vpn -> zone). IPv4, one
    protocol and port list each. See vpn.tofu for the ordering caveat when
    adding entries later.
  EOT
  type = map(object({
    name     = string
    src_ips  = list(string)
    zone     = optional(string, "Internal")
    dst_ips  = list(string)
    protocol = optional(string, "tcp")
    ports    = string
  }))
  default = {}
}

variable "site_to_site" {
  description = <<-EOT
    Routes to the other site over its Site Magic tunnel; remote_cidrs are
    routed into it. peer_name is the name of the tunnel's network entry on
    this controller: the remote gateway's name at the time the connection was
    made. It is NOT updated when that gateway is renamed, and re-creating the
    Site Magic connection renames it - the lookup then fails at plan time.
    null = no routes.
  EOT
  type = object({
    peer_name    = string
    remote_cidrs = list(string)
  })
  default = null
}

variable "dhcp_dns_servers" {
  description = "DNS servers handed out by DHCP on every network at this site. null = the gateway (default)."
  type        = list(string)
  default     = null
}
