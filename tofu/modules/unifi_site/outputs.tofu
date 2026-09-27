output "network_ids" {
  description = "Network key (as in var.networks) => controller network ID."
  value       = { for k, n in unifi_network.this : k => n.id }
}

output "zone_ids" {
  description = "Firewall zone name => zone ID, for site-specific policies."
  value       = local.zone_ids
}
