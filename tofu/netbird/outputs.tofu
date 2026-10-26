# Goes into the ansible vault as netbird_setup_keys; each playbook picks its
# key by name (netbird_setup_key_name).
output "setup_keys" {
  value     = { for k, v in netbird_setup_key.infra : k => v.key }
  sensitive = true
}
