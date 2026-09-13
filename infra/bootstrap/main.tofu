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
      version = "~> 0.113.1"
    }
  }
}

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

resource "terraform_data" "technitium_template" {
  triggers_replace = [
    var.technitium_docker_image,
  ]

  provisioner "local-exec" {
    command = <<-EOT
    set -euo pipefail

    BUILD="${path.root}/.oci"

    rm -rf "$BUILD"
    mkdir -p "$BUILD"

    docker build --platform linux/amd64 -t oci-builder -f oci-build.Dockerfile .

    docker run --rm \
      --privileged \
      --platform linux/amd64 \
      -v "$BUILD:/output" \
      oci-builder \
      bash -euxo pipefail -c '


        # IMPORTANT:
        # Build the rootfs on the container filesystem, not on
        # the macOS bind mount.
        BUILD=/tmp/technitium-build
        DEBIAN_ROOT=$BUILD/debian

        mkdir -p "$DEBIAN_ROOT"

        debootstrap \
          --arch=amd64 \
          --variant=minbase \
          bookworm \
          "$DEBIAN_ROOT" \
          http://deb.debian.org/debian

        mkdir -p "$BUILD/oci"

        skopeo copy \
          --override-os linux \
          --override-arch amd64 \
          docker://technitium/${var.technitium_docker_image} \
          oci:$BUILD/oci/technitium:latest

        umoci unpack --rootless \
          --image $BUILD/oci/technitium:latest \
          $BUILD/technitium-unpacked

        mkdir -p "$DEBIAN_ROOT/opt/technitium"

        cp -a \
          "$BUILD/technitium-unpacked/rootfs/opt/technitium/." \
          "$DEBIAN_ROOT/opt/technitium/"

        mkdir -p "$DEBIAN_ROOT/usr/share/dotnet"

        cp -a \
          "$BUILD/technitium-unpacked/rootfs/usr/share/dotnet/." \
          "$DEBIAN_ROOT/usr/share/dotnet/"

        mkdir -p "$DEBIAN_ROOT/usr/bin"

        cp -a \
          "$BUILD/technitium-unpacked/rootfs/usr/bin/dotnet" \
          "$DEBIAN_ROOT/usr/bin/dotnet"

        mkdir -p "$DEBIAN_ROOT/usr/local/bin"

        cat > "$DEBIAN_ROOT/usr/local/bin/technitium-entrypoint" <<EOF
#!/bin/sh
set -eu

HOST_PREFIX="\$(hostname -s)"

export DNS_SERVER_DOMAIN="\$${HOST_PREFIX}.local.courgettes.club"
${join("\n", [for v in var.technitium_default_variables : "export ${v.key}=${jsonencode(v.value)}"])}

exec /usr/bin/dotnet \
  /opt/technitium/dns/DnsServerApp.dll \
  /etc/dns
EOF

        chmod 755 "$DEBIAN_ROOT/usr/local/bin/technitium-entrypoint"

        mkdir -p "$DEBIAN_ROOT/etc/systemd/system/multi-user.target.wants"

        cat > "$DEBIAN_ROOT/etc/systemd/system/technitium.service" <<EOF
[Unit]
Description=Technitium DNS Server
After=network.target
Wants=network-online.target

[Service]
Type=simple
SyslogIdentifier=dns-server

WorkingDirectory=/opt/technitium/dns
ReadWritePaths=/etc/dns /var/log/technitium/dns

Environment="OPENSSL_ENABLE_SHA1_SIGNATURES=1"

ExecStart=/usr/local/bin/technitium-entrypoint

Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

        ln -sf /etc/systemd/system/technitium.service \
          "$DEBIAN_ROOT/etc/systemd/system/multi-user.target.wants/technitium.service"

        mkdir -p "$DEBIAN_ROOT/etc/dns" "$DEBIAN_ROOT/var/log/technitium/dns"

        echo "==> Installing init system"

        # chroot needs its own resolver to reach deb.debian.org, and /proc,
        # /sys, /dev bind-mounted for the systemd postinst scripts to work.
        cp /etc/resolv.conf "$DEBIAN_ROOT/etc/resolv.conf"
        mount --bind /proc "$DEBIAN_ROOT/proc"
        mount --bind /sys "$DEBIAN_ROOT/sys"
        mount --bind /dev "$DEBIAN_ROOT/dev"

        chroot "$DEBIAN_ROOT" apt-get update

        chroot "$DEBIAN_ROOT" apt-get install -y \
          systemd \
          systemd-sysv \
          ifupdown \
          openssh-server \
          libicu72

        rm -rf "$DEBIAN_ROOT"/var/lib/apt/lists/*

        # Unmount before tar, to avoid archiving live pseudo-fs content.
        umount "$DEBIAN_ROOT/proc" "$DEBIAN_ROOT/sys" "$DEBIAN_ROOT/dev"
        rm -f "$DEBIAN_ROOT/etc/resolv.conf"

        # Run these through chroot: /usr/sbin/init is an absolute symlink
        # (-> /lib/systemd/systemd), which resolves against the wrong root
        # if checked from outside the chroot.
        chroot "$DEBIAN_ROOT" test -e /usr/sbin/init
        chroot "$DEBIAN_ROOT" test -x /usr/bin/sh

        tar \
          --numeric-owner \
          --xattrs \
          --acls \
          --zstd \
          --exclude="./proc/*" \
          --exclude="./sys/*" \
          --exclude="./dev/*" \
          -C "$DEBIAN_ROOT" \
          -cf /output/technitium-lxc.tar.zst \
          .

        echo "==> Finished:"
        ls -lh /output/technitium-lxc.tar.zst
    '
  EOT
  }
}
resource "proxmox_virtual_environment_file" "technitium_template" {
  depends_on = [
    terraform_data.technitium_template
  ]

  content_type = "vztmpl"
  datastore_id = "synology"
  node_name    = var.technitium_node
  overwrite    = true

  source_file {
    path = "${path.root}/.oci/technitium-lxc.tar.zst"
  }
}
module "containers" {
  source = "../modules/lxc"
  containers = {

    dns1 = {
      ctid       = 418
      node       = var.technitium_node
      image_name = proxmox_virtual_environment_file.technitium_template.file_name

      cores  = 1
      cpus   = 1
      memory = 512

      vlan         = 1
      ipv4mode     = "static"
      ipv4_address = "10.10.0.245/23"
      ipv4_gateway = "10.10.0.1"

      ansible_groups = ["dns"]
      ansible_vars = [
        { key = "dns_subdomain", value = "dns1" }
      ]
      ansible_os = "debian"
    }

    dns2 = {
      ctid       = 419
      node       = var.technitium_node
      image_name = proxmox_virtual_environment_file.technitium_template.file_name

      cores  = 1
      cpus   = 1
      memory = 512

      vlan         = 1
      ipv4mode     = "static"
      ipv4_address = "10.10.0.244/23"
      ipv4_gateway = "10.10.0.1"

      ansible_groups = ["dns"]
      ansible_vars = [
        { key = "dns_subdomain", value = "dns2" }
      ]
      ansible_os = "debian"
    }
  }
}