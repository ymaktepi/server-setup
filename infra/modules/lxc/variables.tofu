variable "cts_storage" {
  description = "Default disk storage for storage of container images"
  type        = string
  default     = "synology"
}

variable "linux_bridge" {
  description = "Default linux bridge"
  type        = string
  default     = "vmbr0"
}

variable "ansible_key_file" {
  description = "Path to the SSH public key used for container initialization"
  type        = string
  # todo: move that to 1pass?
  default = "~/.ssh/id_ecdsa.pub"
}

variable "containers" {
  description = "LXC containers to manage"

  type = map(object({
    ctid       = number
    node       = string
    image_name = string
    # whether to spawn the container or not
    present = optional(bool, true)

    domain_name = optional(string, ".nico")

    cores        = number
    cpus         = number
    memory       = number
    disk         = optional(number, 4)
    datastore_id = optional(string, "m2-noraid")

    # omit to have not tagged values
    vlan         = optional(number)
    ipv4mode     = optional(string, "static")
    ipv4_address = string
    ipv4_gateway = string

    unprivileged = optional(bool, true)

    mounts = optional(list(object({
      path      = string
      volume    = string
      size      = optional(string)
      read_only = optional(bool, false)
      backup    = optional(bool, true)
    })), [])

    bind_mount = optional(object({
      source = string
      target = string
      backup = optional(bool, false)
    }))

    vpn = optional(bool, false)

    gpu = optional(bool, false)

    ansible_groups = optional(list(string), [])
    ansible_vars   = optional(list(object({ key = string, value = optional(string, "") })), [])
  }))
}
