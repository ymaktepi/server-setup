
variable "vms" {
  description = "Virtual machines to manage"

  type = map(object({
    vmid       = number
    name       = string
    node       = string
    image_file = string

    cores  = number
    memory = number

    vlan         = number
    ipv4mode     = optional(string, "dhcp")
    ipv4_address = optional(string)
    ipv4_gateway = optional(string)

    gpu       = optional(bool, false)
    disk_size = optional(number, 32)
  }))

  validation {
    condition = alltrue([
      for vm in values(var.vms) :
      vm.ipv4mode == "dhcp" ||
    (
    vm.ipv4_address != null &&
    vm.ipv4_gateway != null
    )
      ])

    error_message = "Static VMs must define ipv4_address and ipv4_gateway."
  }
}
