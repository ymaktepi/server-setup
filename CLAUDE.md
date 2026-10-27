# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository purpose

This is a personal homelab infrastructure repo ("Courgettes Cloud") for a Proxmox cluster split across VLANs (Main/trusted, Entertainment, Guest, Crusted/IoT, DMZ). It has two top-level halves that work together:

- **`tofu/`** — OpenTofu (Terraform) provisions the bare Proxmox LXC containers/VMs.
- **`ansible/`** — Ansible provisions the Proxmox nodes themselves and installs software *inside* the containers/VMs that the OpenTofu stacks create.

**`old/`** is a legacy, no-longer-maintained set of playbooks from before this structure existed — don't extend it.

## The tofu/ansible bridge

`ansible/inventory/inventory.py` is a dynamic Ansible inventory script. It runs `tofu output -json ansible_inventory` in each of `tofu/bootstrap`, `tofu/core`, `tofu/compute` (resolved as `Path(__file__).resolve().parent.parent.parent / "tofu"`, i.e. three levels up from the script, then into the sibling `tofu/` directory) and merges the results into one inventory (grouped by each container's `ansible_groups`, with `ansible_vars` as host vars). This is how Ansible playbooks find hosts that Terraform created — a container only becomes Ansible-reachable once it has a corresponding entry in one of those three `module "containers"` blocks (see `modules/lxc/outputs.tofu`'s `ansible_inventory` output for the exact shape). `ansible/inventory/inventory.conf` separately holds the four Proxmox nodes themselves (`pvenodes` group) plus a few hosts not managed by Terraform at all (`minix`, `gpu`, `infomaniak` — the VPS, see below).

Since `ansible-playbook` runs this script as its own subprocess (not through `make`'s `sops exec-env` wrapping), it can't inherit AWS credentials for the S3 state backend from anywhere — so the script decrypts `tofu/secrets.enc.yaml` itself (via a direct `sops -d` call) and injects `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` into the `tofu output` subprocess's environment. This means `SOPS_AGE_KEY_FILE` must be exported before running *any* `ansible-playbook`/`ansible-inventory` command, not just ones that touch vault secrets — without it, inventory resolution itself fails.

## tofu/ (OpenTofu stacks)

Independent OpenTofu root modules, each with its own state (Garage/S3-compatible backend, bucket `opentofu-state`, addressed by IP:port rather than hostname to avoid a circular dependency on the DNS this repo itself manages):

- **`bootstrap/`** — self-contained: builds a custom Debian LXC template (debootstraps a rootfs, grafts in the `technitium/dns-server` Docker image's files, installs systemd/networking/ssh) because the `bpg/proxmox` provider's native OCI-container support can't override entrypoint/env vars. Deploys it as `dns1`/`dns2` (Technitium DNS), and owns the `actual.courgettes.club` zone: primary on dns1, secondary (zone transfer) on dns2, Cloudflare DoT forwarders, plus any extra hardcoded records (`var.technitium_extra_records`).
- **`core/`** and **`compute/`** — plain container definitions for other services (Traefik, jumphost, arr stack, Nextcloud, etc.). No special bootstrapping concerns.
- **`network-<site>/`** (`network-bole/`, `network-salon/`) — UniFi config per physical site (VLANs, WLANs, firewall, DHCP reservations, etc.) via the `ubiquiti-community/unifi` provider. Each site's UDM is its own controller, so each gets its own stack, state and API key (`TF_VAR_unifi_<site>_api_key` — `sops exec-env` hands every stack every secret, so the names must differ). What must be identical across sites (network names/VLANs/zones, SSIDs, generic firewall policies, settings) lives in **`modules/unifi_site`**; each stack passes its own addressing, reservations, port forwards and host-specific policies, and keeps its WANs. Existing controller config is adopted into state via temporary `import` blocks (removed once applied). Sits *below* the other stacks (they live on its VLANs), so it addresses the controller by IP and depends on nothing else here. Addressing: Bole is `10.10.x`, Salon `10.20.x` (same VLAN IDs/names; the ranges must not overlap for site-to-site routing). Bole's controller is addressed as `10.10.2.1` — historically `10.10.0.1` was ambiguous while Salon still overlapped, and any VLAN gateway address works. Not part of the top-level `make plan`/`make apply`.
- **`netbird/`** — config of the self-hosted NetBird mesh on the VPS (see "The VPS" below), via the `netbirdio/netbird` provider and a service-user token (`TF_VAR_netbird_token`): groups, one-off setup keys for the infra peers (output `setup_keys`, copied into the ansible vault as `netbird_setup_keys`), the `home` network routed by the `vpn` LXC, exit nodes, policies, and a DNS zone making `ldap.sso.courgettes.club` resolve to the VPS's mesh IP for minix only (`vps_mesh_ip`). Mesh range `100.120.0.0/16`, so it doesn't collide with Tailscale's. NetBird's default "All" policy was deleted by hand and isn't in state. Not part of the top-level `make plan`/`make apply` (needs the VPS up).

`bootstrap`, `core` and `compute` share **`modules/lxc`**, the reusable container abstraction (`proxmox_virtual_environment_container` + DNS record registration). Its `containers` input is a map keyed by container name; each value's schema is in `modules/lxc/variables.tofu`. Hostnames are derived as `replace(name, "_", "-") + domain_name` (default `domain_name = ".nico"`). DNS names use the same dash-replacement under `actual.courgettes.club` via `technitium_record` resources (the `darkhonor/technitium` provider), gated by `technitium_register_records` and skipped entirely when that's false.

`modules/vms` is the VM counterpart (`proxmox_virtual_environment_vm` + DNS record + the same `ansible_inventory` shape); `compute` uses it for the `gpu` VM (PCIe passthrough). New VMs boot from a cloud image the module downloads itself (`images`, pinned dated build + checksum, onto `synology`'s `import` content) with a generated cloud-init user-data snippet (`cloud-init.yaml.tftpl`, uploaded over the provider's SSH): hostname, the `ansible` user + key, guest agent. Cloud-init only runs on first boot; the VM ignores later changes to either. `compute`'s `ansible_inventory` output merges both modules.

### Known gotcha: `bootstrap-apply` is 3 stages, not 1

The `darkhonor/technitium` provider unconditionally pings its target server during configuration (no way to disable it), and OpenTofu configures every declared provider whose arguments are statically resolvable regardless of whether any resource's `count`/`for_each` actually uses it — so it can't be configured until dns1/dns2 exist and respond. `make bootstrap-apply` handles this with three `tofu apply` calls using `-exclude` (see the Makefile and the comment above the `provider "technitium"` block in `bootstrap/main.tofu`): containers+tokens first, then the zone/settings (once dns1/dns2 respond), then the actual DNS records. Each stage is a no-op on a routine re-apply. `make bootstrap-destroy` needs the same two API tokens for the same reason.

### UniFi sites (`network-<site>`): how they're linked, and known gotchas

- **Sites.** Bole (`10.10.x`) hosts the Proxmox cluster, the DMZ, dns1/dns2 and Garage (the tofu state backend); Salon (`10.20.x`) has no custom infra. Both use the same VLAN IDs, network names, zones and SSIDs from `modules/unifi_site`.
- **Site-to-site.** UniFi Site Magic (set up in Site Manager, not in tofu) provides the WireGuard tunnel, but on these controllers it never installs routes for the remote subnets. `modules/unifi_site/site_to_site.tofu` adds them as static routes into the tunnel's network entry, looked up by name — the remote gateway's name *when the connection was made* (`UDR7` on Bole, `Bole-Router` on Salon); re-creating Site Magic renames it and breaks the lookup.
- **VPN lockdown.** UniFi's default lets VPN traffic into Internal/Dmz/Gateway. `vpn.tofu` blocks it except `vpn_inbound_allow` (per site). Policies can't be ordered through the provider — the controller appends new ones — so the block policies are re-created (`replace_triggered_by`) whenever an allow or return rule changes, to stay behind it. Each blocked zone needs an explicit RESPOND_ONLY return rule (`vpn_return`): the controller's own auto-generated respond rules always sit after user policies, i.e. after the blocks (this silently broke DNS replies to Salon's Crusted devices).
- **Salon's DNS comes from Bole.** Salon's DHCP hands out dns1/dns2 over the tunnel (Salon's gateway itself uses public DNS). If the tunnel is down, Salon's clients have no DNS.
- **Reaching the other site.** Only the user's laptop (reserved at `.20` Wi-Fi / `.21` Ethernet on both sites' Default networks, `laptop_*` allows) gets full access across the tunnel — including Garage and the other gateway's UI/API on 443 (no SSH) — so tofu works from either site without Tailscale. Any other device needs Tailscale; from such a device, `make network-*` fails with an S3 timeout.
- **Controller quirks hit so far:** zone membership only sticks when set on the zone (`network_ids`), not via a network's `firewall_zone_id`; at least one WAN must be weighted and failover priorities must be unique at every step of an apply; a network's IPv6 prefix delegation needs its WAN to already be DHCPv6 (may take a second apply); a factory-reset controller forces WAN `setting_preference = "auto"` and needs the zone-based firewall enabled in the UI before tofu can manage zones.

### Commands

```bash
cd tofu
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"   # secrets come from sops+age, see tofu/README.md — no external app/service needed
make bootstrap-apply     # only stack safe to apply routinely — self-contained 3-stage dance, see above
make bootstrap-destroy
make bootstrap-plan
make core-plan / make core-apply
make compute-plan / make compute-apply
make network-bole-plan / make network-bole-apply   # UniFi, one pair per site (also network-salon-*); not chained into make plan/apply
make netbird-plan / make netbird-apply             # NetBird on the VPS; not chained into make plan/apply (netbird-apply-idp: first stage, see README)
make plan / make apply   # runs all three stacks in sequence
make format              # tofu fmt across all stacks + modules
make install             # tofu init -upgrade across all stacks (needed in a fresh checkout/worktree: the ansible inventory script runs `tofu output`)
```

Every target above is wrapped in `$(SOPS_EXEC)` (`sops exec-env secrets.enc.yaml ...`) in the Makefile, which decrypts `tofu/secrets.enc.yaml` into environment variables (`TF_VAR_*`, `AWS_*`) for that one command. `sops exec-env`'s "command to run" must be passed as a single argument — splitting it across multiple argv entries hits a real sops parsing bug (`error: missing file to decrypt`) — which is why every Makefile recipe quotes its command as one string.

`core` and `compute` run this homelab's actual production workloads, and the `network-<site>` stacks are the live networks everything (including the state backend) depends on — don't run `core-apply`/`compute-apply`/`network-<site>-apply` (or the top-level `make apply`/`make plan`, which chain all three) without the user's explicit go-ahead for that specific action, even though `bootstrap-apply`/`bootstrap-destroy` are fine to run routinely.

## ansible/ (Ansible)

```bash
cd ansible
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"   # same age identity as tofu/'s Terraform secrets
ansible pvenodes -m ping                              # sanity-check connectivity to the 4 Proxmox nodes
ansible-playbook playbooks/pve/pve_onboard.yml -e 'ansible_user=root'   # one-time: create the ansible user on a fresh node
ansible-playbook playbooks/update/update_<service>_cts.yml
ansible-playbook playbooks/update_all.yml              # every update playbook, for VMs, CTs and Proxmox nodes
```

Secrets live in `inventory/group_vars/all/vault.sops.yaml`, sops-encrypted (same root-level `.sops.yaml`/age recipient as `tofu/secrets.enc.yaml` — one shared config covers both). The `community.sops` vars plugin (enabled via `ansible.cfg`'s `vars_plugins_enabled`) decrypts it transparently at vars-loading time, exactly like the `ansible-vault`-encrypted `vault-file` it replaced — so every role/template still references secrets as plain `{{ variable_name }}`, no `lookup('env', ...)` involved. `ansible.cfg` points `inventory=./inventory/` (both the static `.conf` and the dynamic `.py` script are merged).

Ansible doesn't create containers or VMs anymore — OpenTofu does (`modules/lxc`, `modules/vms`); Ansible only installs software inside them. `roles/install_*` are per-service installers (arr, nextcloud, traefik, jumphost, k3s, technitium, etc.) invoked by the `update/update_*_cts.yml` playbooks against the Terraform-sourced inventory groups.

## The VPS (`infomaniak_vps`)

The Infomaniak VPS runs what must stay up when home is down (`playbooks/update/update_infomaniak.yml`): TeamSpeak, Traefik (`install_traefik_cts` with the `vps-*` templates, certs via the Infomaniak DNS challenge), Authelia + lldap (`install_authelia`) and the NetBird server (`install_netbird_server`: management, signal, relay, STUN and an embedded Dex IdP in one container). The manual install steps and their pitfalls are in the root `README.md` ("NetBird and SSO (VPS)") — read it before touching any of this.

- **SSO.** `sso.courgettes.club` is Authelia's portal; protected apps live at `<app>.sso.courgettes.club` (one cookie scope). lldap's UI (`lldap.sso.courgettes.club`) and LDAPS (`ldap.sso.courgettes.club:636`) only accept mesh addresses (`100.64.0.0/10`). Authelia is also the OIDC provider NetBird's embedded IdP delegates to (a connector, `netbird_identity_provider` in tofu); the client needs `client_secret_basic`, a `claims_policy` putting `name` in the ID token, and the redirect URI `https://netbird.courgettes.club/oauth2/callback` (no connector id). The connector is of type `pocketid` (generic OIDC that also asks for the `groups` scope; `oidc` doesn't), and `groups` is in the ID token: lldap groups become NetBird groups at each login (JWT group sync). NetBird only fills groups it created from the claim, so `netbird_admins` (full access) is a data source in tofu, not a resource, and must exist (someone in it logged in once) before a full apply — `make netbird-apply-idp` covers the first stage.
- **Mesh peers** (`install_netbird_client`, enrolled once with `netbird_setup_keys[netbird_setup_key_name]`): the VPS (`vps`), the `vpn` LXC (`home-router`, needs `/dev/net/tun` — `devices` in `modules/lxc`), minix (`jellyfin`). Jellyfin's LDAP plugin (`install_jellyfin/templates/LDAP-Auth.xml`) talks to the VPS's lldap over the mesh; streaming itself still goes through the home DMZ Traefik.
- **Tailscale** still runs on the `vpn` LXC alongside NetBird, until NetBird has been tested enough to replace it.
- The home DMZ Traefik no longer runs Authelia/lldap; it only serves public sites.

## Network conventions

- `local.courgettes.club` — pre-existing convention used by Traefik/nginx configs and each service's own `*_DOMAIN` env var.
- `actual.courgettes.club` — newer zone, authoritative on dns1/dns2, auto-populated with one A record per Terraform-managed container plus any `technitium_extra_records` entries. Distinct from `local.courgettes.club`; not a replacement for it.
- `proxy.courgettes.club` — public-facing alias for the ISP router; DMZ Traefik terminates TLS for anything CNAMEd to it.
- `sso.courgettes.club`, `*.sso.courgettes.club`, `netbird.courgettes.club` — point at the VPS, whose Traefik terminates TLS for them.
