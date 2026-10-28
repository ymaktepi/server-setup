output "ansible_inventory" {
  value = module.containers.ansible_inventory
}
# What Technitium serves, for the stacks resolving through it from elsewhere
# (netbird's split DNS): dns1 (Primary) first, and every zone tofu creates.
output "dns" {
  value = {
    servers = [for name in ["dns1", "dns2"] : local.technitium_instances[name]]
    zones   = concat([var.technitium_zone], keys(var.technitium_wildcard_zones))
  }
}
