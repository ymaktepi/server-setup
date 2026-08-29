output "ansible_inventory" {
  value = {
    for name, container in proxmox_virtual_environment_container.this :
    name => {
      groups = var.containers[name].ansible_groups
      # set a default ansible_user. can still be overridden in the ansible_vars
      vars = merge({ ansible_user = "root" }, { for v in var.containers[name].ansible_vars : v.key => v.value }, { ansible_host = split("/", container.initialization[0].ip_config[0].ipv4[0].address)[0] })
    }
  }
}