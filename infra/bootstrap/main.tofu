terraform {
  backend "s3" {
    bucket       = "opentofu-state"
    key          = "homelab-bootstrap.tfstate"
    region       = "garage"
    use_lockfile = true

    endpoints = {
      s3 = "https://nas-2.nico"
    }

    insecure                    = true
    skip_region_validation      = true
    skip_credentials_validation = true
    use_path_style              = true
  }
}

terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.111"
    }
  }
}

#module "proxmox" {
#  source = "../modules/proxmox"
#}

variable "technitium_node" {
  type    = string
  default = "proxmox2"
}

variable "technitium_docker_image" {
  type    = string
  default = "dns-server:15.4.0"
}

variable "technitium_default_variables" {
  type = list(object({ key = string, value = string }))
  default = [
    { key = "DNS_SERVER_ADMIN_PASSWORD", value = "CHANGEME" },
    { key = "DNS_SERVER_WEB_SERVICE_ENABLE_HTTPS", value = "true" },
    { key = "DNS_SERVER_WEB_SERVICE_USE_SELF_SIGNED_CERT", value = "true" },
    { key = "DNS_SERVER_WEB_SERVICE_HTTP_TO_TLS_REDIRECT", value = "true" },
    { key = "DNS_SERVER_WEB_SERVICE_REVERSE_PROXY_ADDRESSES", value = "10.10.0.250" },
    { key = "DNS_SERVER_WEB_SERVICE_HTTP_PORT", value = "80" },
    { key = "DNS_SERVER_WEB_SERVICE_HTTPS_PORT", value = "443" },
    { key = "DNS_SERVER_LOG_USING_LOCAL_TIME", value = "true" },
    { key = "DNS_SERVER_LOG_MAX_LOG_FILE_DAYS", value = "30" },
  ]
}

resource "proxmox_virtual_environment_file" "dns_entrypoint" {
  content_type = "snippets"
  datastore_id = "synology"
  node_name = var.technitium_node
  timeout_upload = 20
  overwrite = true
  upload_mode = "sftp"
  file_mode = "766"
  source_raw {
    data      = <<-EOF
    IFS='.' read -a HOST_PREFIX <<< $HOSTNAME
    export DNS_SERVER_DOMAIN=$HOST_PREFIX.local.courgettes.club
    ${join("\n", [for v in var.technitium_default_variables : "export ${v.key}=${jsonencode(v.value)}"])}

    exec /usr/bin/dotnet "$@"
    EOF
    file_name = "dns_config_entrypoint.sh"
  }
}

resource "proxmox_oci_image" "technitium" {
  node_name    = var.technitium_node
  datastore_id = "synology"
  reference    = format("%s/%s", "docker.io/technitium", var.technitium_docker_image)

  upload_timeout = 900
}

module "containers" {
  source = "../modules/lxc"
  containers = {

    dns1 = {
      ctid       = 418
      node       = var.technitium_node
      image_name = proxmox_oci_image.technitium.file_name

      cores  = 1
      cpus   = 1
      memory = 512

      vlan         = 1
      ipv4mode     = "static"
      ipv4_address = "10.10.0.245/23"
      ipv4_gateway = "10.10.0.1"


      entrypoint = "/mnt/entrypoint.sh"

      bind_mount = {
        source = format("/mnt/pve/synology/snippets/%s", proxmox_virtual_environment_file.dns_entrypoint.file_name)
        target = "/mnt/entrypoint.sh"
        backup = false
      }

      ansible_groups = ["dns"]
      ansible_vars = [
        { key = "dns_subdomain", value = "dns1" }
      ]
    }

    dns2 = {
      ctid       = 419
      node       = var.technitium_node
      image_name = proxmox_oci_image.technitium.file_name

      cores  = 1
      cpus   = 1
      memory = 512

      vlan         = 1
      ipv4mode     = "static"
      ipv4_address = "10.10.0.244/23"
      ipv4_gateway = "10.10.0.1"

      entrypoint = "/mnt/entrypoint.sh"

      bind_mount = {
        source = format("/mnt/pve/synology/snippets/%s", proxmox_virtual_environment_file.dns_entrypoint.file_name)
        target = "/mnt/entrypoint.sh"
        backup = false
      }

      ansible_groups = ["dns"]
      ansible_vars = [
        { key = "dns_subdomain", value = "dns2" }
      ]
    }
  }
}