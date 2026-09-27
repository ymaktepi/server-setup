# Address/port groups referenced by firewall policies (firewall_policies.tofu).
locals {
  firewall_groups = {
    http_https_ssh_unifihttps = {
      name    = "http,https,ssh,unifihttps"
      type    = "port-group"
      members = ["80", "22", "443", "8443"]
    }
  }
}

resource "unifi_firewall_group" "this" {
  for_each = local.firewall_groups

  name    = each.value.name
  type    = each.value.type
  members = each.value.members
}
