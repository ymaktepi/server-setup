output "ansible_inventory" {
  value = merge(module.containers.ansible_inventory, module.vms.ansible_inventory)
}
