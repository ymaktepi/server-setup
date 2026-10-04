variable "linux_bridge" {
  description = "Default linux bridge"
  type        = string
  default     = "vmbr0"
}

variable "technitium_zone" {
  description = "Technitium DNS zone that managed VMs get registered in"
  type        = string
  default     = "actual.courgettes.club"
}

variable "technitium_register_records" {
  description = "Whether to create A records for these VMs (see modules/lxc)."
  type        = bool
  default     = true
}

variable "images" {
  description = <<-EOT
    Cloud images to download (on the Proxmox side) for VMs to boot from, keyed
    by the name VMs refer to in `image`. Pin a dated build (not .../latest/),
    or the checksum goes stale on the next point release.
  EOT
  type = map(object({
    url                = string
    checksum           = string
    checksum_algorithm = optional(string, "sha512")
  }))
  default = {}
}

variable "image_datastore" {
  description = "Shared storage with the `import` content type, for downloaded images"
  type        = string
  default     = "synology"
}

variable "download_node" {
  description = "Node that performs the image downloads (any node with access to image_datastore)"
  type        = string
  default     = "proxmox2"
}

variable "snippets_datastore" {
  description = "Shared storage with the `snippets` content type, for generated cloud-init user-data"
  type        = string
  default     = "synology"
}

variable "ansible_key_file" {
  description = "SSH public key put on the cloud-init user (same as modules/lxc)"
  type        = string
  default     = "~/.ssh/id_ecdsa.pub"
}

variable "timezone" {
  type    = string
  default = "Europe/Zurich"
}

variable "locale" {
  type    = string
  default = "en_US.UTF-8"
}

variable "vms" {
  description = "Virtual machines to manage. The key is the VM name."

  type = map(object({
    vmid = number
    node = string

    cores        = number
    memory       = number # MB, dedicated (ballooning off)
    disk_size    = optional(number, 32)
    datastore_id = optional(string, "m2-noraid")
    # key into var.images to create the disk from; only used at creation
    # (null for a VM imported into state)
    image = optional(string)

    # cloud-init: by default a user-data snippet is generated (hostname, the
    # admin user + SSH key, guest agent, timezone/locale). Set
    # user_data_file_id to use an existing snippet instead.
    domain_name       = optional(string, ".nico")
    cloud_init_user   = optional(string, "ansible")
    user_data_file_id = optional(string)

    # desired power state; on_boot = start with the node
    started = optional(bool, true)
    on_boot = optional(bool, false)

    machine = optional(string) # e.g. "q35" for PCIe passthrough
    # PCI passthrough. Use `mapping` (a proxmox_hardware_mapping_pci name):
    # Proxmox only lets root@pam set a raw `id` (host PCI address, e.g.
    # "01:00.0"), so an API token gets "only root can set 'hostpci0' config
    # for non-mapped devices".
    hostpci = optional(list(object({
      mapping = optional(string)
      id      = optional(string)
      pcie    = optional(bool, true)
      rombar  = optional(bool, true)
    })), [])

    vlan         = number
    mac_address  = optional(string) # keep an existing VM's MAC on import
    ipv4mode     = optional(string, "dhcp")
    ipv4_address = optional(string)
    ipv4_gateway = optional(string)

    ansible_groups = optional(list(string), [])
    ansible_os     = optional(string, "debian")
    ansible_vars   = optional(list(object({ key = string, value = optional(string, "") })), [])
  }))

  validation {
    condition = alltrue([
      for vm in values(var.vms) :
      vm.ipv4mode == "dhcp" || (vm.ipv4_address != null && vm.ipv4_gateway != null)
    ])
    error_message = "Static VMs must define ipv4_address and ipv4_gateway."
  }

  validation {
    condition = alltrue(flatten([
      for vm in values(var.vms) : [for d in vm.hostpci : (d.mapping == null) != (d.id == null)]
    ]))
    error_message = "Each hostpci entry needs exactly one of `mapping` or `id`."
  }
}
