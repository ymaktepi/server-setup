# Same shape as modules/lxc's, so ansible/inventory/inventory.py picks VMs up
# (as host_<key>) once the stack merges it into its ansible_inventory output.
output "ansible_inventory" {
  value = {
    for name, vm in var.vms :
    name => {
      groups = concat(vm.ansible_groups, [vm.ansible_os])
      vars = merge(
        { ansible_user = "root" },
        { for v in vm.ansible_vars : v.key => v.value },
        vm.ipv4mode == "static" ? { ansible_host = split("/", vm.ipv4_address)[0] } : {},
      )
    }
  }
}
