terraform {
  backend "s3" {
    bucket       = "opentofu-state"
    key          = "homelab-bootstrap.tfstate"
    region       = "garage"
    use_lockfile = true

    endpoints = {
      s3 = "https://10.10.0.251:8443"
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
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    technitium = {
      source  = "darkhonor/technitium"
      version = "~> 1.2"
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
    # The admin password is baked into the image at build time (see the
    # entrypoint-script heredoc below), so changing it needs a rebuild too.
    var.technitium_admin_password,
    # Bump this whenever the build script below changes, so a rebuild is
    # actually triggered - it's not otherwise reflected in any tracked
    # attribute.
    "build-script-v4",
  ]

  provisioner "local-exec" {
    environment = {
      ADMIN_PASSWORD = var.technitium_admin_password
    }
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
      -e ADMIN_PASSWORD \
      --dns 1.1.1.1 \
      --dns 1.0.0.1 \
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
export DNS_SERVER_ADMIN_PASSWORD="$ADMIN_PASSWORD"
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
          libicu72 \
          ca-certificates

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

  technitium_zone = var.technitium_zone

  # Plain passthrough - NOT threaded through technitium_zone.primary's id,
  # because for_each can't depend on a value that's only known after apply
  # (which .id genuinely is the first time the zone is created in the same
  # apply as the records). On a from-scratch bootstrap, apply once with
  # `-exclude=module.containers.technitium_record.containers` so the zone
  # exists first, then apply normally - same two-stage shape as the API
  # token/provider bootstrapping issue described below, just resolved with
  # -exclude instead of a variable since threading isn't possible here.
  technitium_register_records = var.technitium_register_records

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

variable "technitium_zone" {
  type    = string
  default = "actual.courgettes.club"
}

locals {
  # dns1 is the Primary for var.technitium_zone (accepts API record writes);
  # dns2 is a Secondary (zone transfer from dns1).
  technitium_instances = module.containers.ip_addresses
}

# Creates a non-expiring API token on each Technitium instance (using the
# current admin password). dns1's token is what the "technitium" provider
# below uses for everything (zone + records); dns2's is only needed for the
# one local-exec call further down that the provider can't do itself. Retries
# until each instance's HTTPS API is reachable, since the container has just
# booted.
resource "terraform_data" "technitium_api_token" {
  for_each = local.technitium_instances

  triggers_replace = [
    each.value,
  ]

  provisioner "local-exec" {
    environment = {
      ADMIN_PASSWORD = var.technitium_admin_password
    }
    command = <<-EOT
    set -euo pipefail

    TOKEN_DIR="${path.root}/.technitium"
    mkdir -p "$TOKEN_DIR"

    for i in $(seq 1 30); do
      RESP="$(curl -sk -m 5 -G "https://${each.value}/api/user/createToken" \
        --data-urlencode "user=admin" \
        --data-urlencode "pass=$ADMIN_PASSWORD" \
        --data-urlencode "tokenName=terraform" || true)"
      TOKEN="$(printf '%s' "$RESP" | jq -r '.token // empty')"
      if [ -n "$TOKEN" ]; then
        printf '%s' "$TOKEN" > "$TOKEN_DIR/${each.key}-token"
        exit 0
      fi
      sleep 2
    done

    echo "Failed to obtain Technitium API token for ${each.key} (${each.value})" >&2
    printf '%s\n' "$${RESP:-}" >&2
    exit 1
    EOT
  }
}

data "local_file" "technitium_api_token" {
  for_each = local.technitium_instances

  filename   = "${path.root}/.technitium/${each.key}-token"
  depends_on = [terraform_data.technitium_api_token]
}

# server_url is the literal static IP configured on dns1 below, NOT
# local.technitium_instances["dns1"] (module.containers.ip_addresses) - that
# output is read back from the container resource's own attributes, so it's
# "known after apply" (unresolved) until dns1 actually exists, which would
# leave this provider block unconfigurable on a from-scratch apply.
#
# Same "provider blocks can't reference a same-apply resource/data source"
# issue as before: data.local_file.technitium_api_token["dns1"].content is
# only known after terraform_data.technitium_api_token runs, but the
# provider needs a value upfront. So this reads from var.technitium_api_token
# instead (blank on the very first apply - the placeholder keeps the
# provider config valid), and technitium_zone.primary / modules/lxc's
# technitium_record resources are skipped (via technitium_register_records)
# until the real token from the output below is fed back in as
# TF_VAR_technitium_api_token (same as core/compute consume it).
#
# On a genuinely from-scratch apply (empty state), this provider still
# unconditionally pings the server during configuration with no way to skip
# it (verified against the provider's source), and dns1 won't exist/respond
# yet. Setting technitium_register_records=false alone is NOT enough to
# avoid this - OpenTofu still configures (and pings) every declared provider
# whose arguments are statically resolvable, regardless of whether any
# resource's count/for_each ends up using it (confirmed empirically: this
# still fails even with technitium_register_records=false). The actual fix
# is -exclude, which skips building those resources into the plan/graph at
# all:
#
#   1. tofu apply -exclude=technitium_zone.primary \
#        -exclude=module.containers.technitium_record.containers
#      (creates dns1/dns2 + API tokens only; the provider is never touched)
#   2. export TF_VAR_technitium_api_token="$(cat .technitium/dns1-token)"
#      tofu apply -exclude=module.containers.technitium_record.containers
#      (dns1 now exists and responds, so the provider can configure; this
#      creates the zone + secondary zone)
#   3. tofu apply
#      (creates the actual A records, now that the zone exists)
provider "technitium" {
  server_url      = "https://10.10.0.245"
  api_token       = var.technitium_api_token != "" ? var.technitium_api_token : "placeholder"
  skip_tls_verify = true
}

# Same shape as the default (dns1) provider above, and the same reason:
# static literal IP, placeholder token until the real one (dns2's, not
# dns1's) is fed back in as TF_VAR_technitium_api_token_dns2.
provider "technitium" {
  alias           = "dns2"
  server_url      = "https://10.10.0.244"
  api_token       = var.technitium_api_token_dns2 != "" ? var.technitium_api_token_dns2 : "placeholder"
  skip_tls_verify = true
}

resource "technitium_zone" "primary" {
  count = var.technitium_register_records ? 1 : 0

  name = var.technitium_zone
  type = "Primary"

  # Scoped to dns2 specifically rather than a broad "Allow" - only dns2
  # actually needs to pull this zone. notify ensures dns2 gets pushed new
  # records immediately instead of waiting for its SOA refresh timer.
  allow_transfer = [local.technitium_instances["dns2"]]
  notify         = [local.technitium_instances["dns2"]]
}

# The technitium provider's zone resource has no way to set a Secondary
# zone's primary server address (verified against its source - only name,
# type and soa_serial_date_scheme are sent on create), so this one zone
# stays a local-exec call. allow_transfer above is already in place by the
# time this runs, so the initial transfer attempt succeeds immediately.
resource "terraform_data" "technitium_zone_secondary" {
  count = var.technitium_register_records ? 1 : 0

  depends_on = [technitium_zone.primary]

  provisioner "local-exec" {
    environment = {
      API_TOKEN = data.local_file.technitium_api_token["dns2"].content
    }
    command = <<-EOT
    set -euo pipefail
    RESP="$(curl -sk -m 10 -G "https://${local.technitium_instances["dns2"]}/api/zones/create" \
      --data-urlencode "token=$API_TOKEN" \
      --data-urlencode "zone=${var.technitium_zone}" \
      --data-urlencode "type=Secondary" \
      --data-urlencode "primaryNameServerAddresses=${local.technitium_instances["dns1"]}")"
    printf '%s' "$RESP" | jq -e '.status == "ok"' > /dev/null || {
      echo "Failed to create secondary zone ${var.technitium_zone} on dns2:" >&2
      echo "$RESP" >&2
      exit 1
    }
    EOT
  }
}

# Server settings (forwarders included) aren't synced between nodes - we're
# not using Technitium's clustering feature - so this needs applying to both
# dns1 and dns2 independently. Only the fields set here get sent to the API
# (verified against the provider's source: unset schema fields are dropped
# from the request, not reset to zero-values), so this can't clobber other
# settings baked in at image-build time (admin password, HTTPS, etc).
resource "technitium_server_settings" "dns1_forwarders" {
  count = var.technitium_register_records ? 1 : 0

  forwarders         = var.technitium_forwarders
  forwarder_protocol = var.technitium_forwarder_protocol
}

resource "technitium_server_settings" "dns2_forwarders" {
  provider = technitium.dns2
  count    = var.technitium_register_records ? 1 : 0

  forwarders         = var.technitium_forwarders
  forwarder_protocol = var.technitium_forwarder_protocol
}

# Extra hardcoded records (var.technitium_extra_records) - same pattern as
# modules/lxc's per-container technitium_record resources. Only written to
# dns1 (the Primary); dns2 picks them up via zone transfer like everything
# else in this zone.
resource "technitium_record" "extra" {
  for_each = var.technitium_register_records ? { for r in var.technitium_extra_records : r.subdomain => r } : {}

  # zone is just var.technitium_zone (a plain string), so it doesn't create
  # an implicit dependency on the zone resource - needs an explicit
  # depends_on or this can race the zone create on a from-scratch apply
  # (confirmed: this broke on the first genuinely fresh bootstrap since this
  # resource was added, while technitium_record.wildcard - which already
  # had this fix - didn't).
  depends_on = [technitium_zone.primary]

  zone  = var.technitium_zone
  name  = "${each.value.subdomain}.${var.technitium_zone}"
  type  = "A"
  value = each.value.ip
  ttl   = 3600
}

# Static wildcard zones (var.technitium_wildcard_zones), e.g. *.local.
# courgettes.club -> traefik_default. Each gets its own Primary zone (a
# wildcard record needs to live in a zone that's actually authoritative for
# that domain - it can't just be another record under var.technitium_zone)
# plus a Secondary on dns2, same pattern as var.technitium_zone above. Note
# this only covers the wildcard label itself, not the bare apex (e.g.
# local.courgettes.club with no subdomain) - add an explicit record for that
# too if it's ever needed.
resource "technitium_zone" "wildcard" {
  for_each = var.technitium_register_records ? var.technitium_wildcard_zones : {}

  name = each.key
  type = "Primary"

  allow_transfer = [local.technitium_instances["dns2"]]
  notify         = [local.technitium_instances["dns2"]]
}

resource "technitium_record" "wildcard" {
  for_each = var.technitium_register_records ? var.technitium_wildcard_zones : {}

  # zone is just each.key (a plain string), so it doesn't create an implicit
  # dependency on the zone resource the way a resource-attribute reference
  # would - needs an explicit depends_on or this could race the zone create.
  depends_on = [technitium_zone.wildcard]

  zone  = each.key
  name  = "*.${each.key}"
  type  = "A"
  value = each.value
  ttl   = 3600
}

# Same reasoning as technitium_zone_secondary above: the provider can't set
# a Secondary zone's primary server address, so this stays local-exec.
resource "terraform_data" "technitium_wildcard_zone_secondary" {
  for_each = var.technitium_register_records ? var.technitium_wildcard_zones : {}

  depends_on = [
    technitium_zone.wildcard,
    technitium_record.wildcard,
  ]

  provisioner "local-exec" {
    environment = {
      API_TOKEN = data.local_file.technitium_api_token["dns2"].content
    }
    command = <<-EOT
    set -euo pipefail
    RESP="$(curl -sk -m 10 -G "https://${local.technitium_instances["dns2"]}/api/zones/create" \
      --data-urlencode "token=$API_TOKEN" \
      --data-urlencode "zone=${each.key}" \
      --data-urlencode "type=Secondary" \
      --data-urlencode "primaryNameServerAddresses=${local.technitium_instances["dns1"]}")"
    printf '%s' "$RESP" | jq -e '.status == "ok"' > /dev/null || {
      echo "Failed to create secondary zone ${each.key} on dns2:" >&2
      echo "$RESP" >&2
      exit 1
    }
    EOT
  }
}

# technitium_zone_secondary gained a count argument (see comment above it).
moved {
  from = terraform_data.technitium_zone_secondary
  to   = terraform_data.technitium_zone_secondary[0]
}

# notify (set on technitium_zone.primary) only fires on a SOA-serial change
# going forward - it doesn't retroactively push changes dns2 missed before
# notify was configured, or before dns2 existed at all. Re-triggers whenever
# the container map changes (name/IP added/removed/changed), which is a
# reasonable proxy for "dns2 might be behind" without needing to hash the
# actual DNS record set.
resource "terraform_data" "technitium_zone_secondary_resync" {
  count = var.technitium_register_records ? 1 : 0

  triggers_replace = [
    sha256(jsonencode(local.technitium_instances)),
  ]

  depends_on = [
    terraform_data.technitium_zone_secondary,
    module.containers,
  ]

  provisioner "local-exec" {
    environment = {
      API_TOKEN = data.local_file.technitium_api_token["dns2"].content
    }
    command = <<-EOT
    set -euo pipefail
    RESP="$(curl -sk -m 10 -G "https://${local.technitium_instances["dns2"]}/api/zones/resync" \
      --data-urlencode "token=$API_TOKEN" \
      --data-urlencode "zone=${var.technitium_zone}")"
    printf '%s' "$RESP" | jq -e '.status == "ok"' > /dev/null || {
      echo "Failed to resync secondary zone ${var.technitium_zone} on dns2:" >&2
      echo "$RESP" >&2
      exit 1
    }
    EOT
  }
}

output "technitium_api_token" {
  value     = data.local_file.technitium_api_token["dns1"].content
  sensitive = true
}

output "technitium_api_token_dns2" {
  value     = data.local_file.technitium_api_token["dns2"].content
  sensitive = true
}