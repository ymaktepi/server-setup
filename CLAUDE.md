# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository purpose

This is a personal homelab infrastructure repo ("Courgettes Cloud") for a Proxmox cluster split across VLANs (Main/trusted, Entertainment, Guest, Crusted/IoT, DMZ). It has two halves that work together:

- **`infra/`** — OpenTofu (Terraform) provisions the bare Proxmox LXC containers/VMs.
- **`proxmox/`** — Ansible provisions the Proxmox nodes themselves and installs software *inside* the containers/VMs that `infra/` creates.

**`old/`** is a legacy, no-longer-maintained set of playbooks from before this structure existed — don't extend it.

## The infra/proxmox bridge

`proxmox/inventory/inventory.py` is a dynamic Ansible inventory script. It runs `tofu output -json ansible_inventory` in each of `infra/bootstrap`, `infra/core`, `infra/compute` and merges the results into one inventory (grouped by each container's `ansible_groups`, with `ansible_vars` as host vars). This is how Ansible playbooks find hosts that Terraform created — a container only becomes Ansible-reachable once it has a corresponding entry in one of those three `module "containers"` blocks (see `modules/lxc/outputs.tofu`'s `ansible_inventory` output for the exact shape). `proxmox/inventory/inventory.conf` separately holds the four Proxmox nodes themselves (`pvenodes` group) plus a few hosts not managed by Terraform at all (`minix`, `gpu`, `infomaniak`).

## infra/ (OpenTofu)

Three **independent** OpenTofu root modules, each with its own state (Garage/S3-compatible backend at `nas-2.nico`, bucket `opentofu-state`):

- **`bootstrap/`** — self-contained: builds a custom Debian LXC template (debootstraps a rootfs, grafts in the `technitium/dns-server` Docker image's files, installs systemd/networking/ssh) because the `bpg/proxmox` provider's native OCI-container support can't override entrypoint/env vars. Deploys it as `dns1`/`dns2` (Technitium DNS), and owns the `actual.courgettes.club` zone: primary on dns1, secondary (zone transfer) on dns2, Cloudflare DoT forwarders, plus any extra hardcoded records (`var.technitium_extra_records`).
- **`core/`** and **`compute/`** — plain container definitions for other services (Traefik, jumphost, arr stack, Nextcloud, etc.). No special bootstrapping concerns.

All three share **`modules/lxc`**, the reusable container abstraction (`proxmox_virtual_environment_container` + DNS record registration). Its `containers` input is a map keyed by container name; each value's schema is in `modules/lxc/variables.tofu`. Hostnames are derived as `replace(name, "_", "-") + domain_name` (default `domain_name = ".nico"`). DNS names use the same dash-replacement under `actual.courgettes.club` via `technitium_record` resources (the `darkhonor/technitium` provider), gated by `technitium_register_records` and skipped entirely when that's false.

`modules/vms` and `modules/proxmox` exist but are currently unused/commented out everywhere.

### Known gotcha: `bootstrap-apply` is 3 stages, not 1

The `darkhonor/technitium` provider unconditionally pings its target server during configuration (no way to disable it), and OpenTofu configures every declared provider whose arguments are statically resolvable regardless of whether any resource's `count`/`for_each` actually uses it — so it can't be configured until dns1/dns2 exist and respond. `make bootstrap-apply` handles this with three `tofu apply` calls using `-exclude` (see the Makefile and the comment above the `provider "technitium"` block in `bootstrap/main.tofu`): containers+tokens first, then the zone/settings (once dns1/dns2 respond), then the actual DNS records. Each stage is a no-op on a routine re-apply. `make bootstrap-destroy` needs the same two API tokens for the same reason.

### Commands

```bash
cd infra
make login              # prints `export TF_VAR_...`/AWS_* lines sourced from 1Password (op) — eval "$(make login)" before anything else
make bootstrap-apply     # only stack safe to apply routinely — self-contained 3-stage dance, see above
make bootstrap-destroy
make bootstrap-plan
make core-plan / make core-apply
make compute-plan / make compute-apply
make plan / make apply   # runs all three stacks in sequence
make format              # tofu fmt across all three
make install             # tofu init -upgrade across all three
```

`core` and `compute` run this homelab's actual production workloads — don't run `core-apply`/`compute-apply` (or the top-level `make apply`/`make plan`, which chain all three) without the user's explicit go-ahead for that specific action, even though `bootstrap-apply`/`bootstrap-destroy` are fine to run routinely.

## proxmox/ (Ansible)

```bash
cd proxmox
ansible pvenodes -m ping                              # sanity-check connectivity to the 4 Proxmox nodes
ansible-playbook playbooks/pve/pve_onboard.yml -e 'ansible_user=root'   # one-time: create the ansible user on a fresh node
ansible-playbook playbooks/provisioning/build_cts.yml  # create/start/stop LXCs from variable_files/cts (legacy path — most new containers go through infra/ now)
ansible-playbook playbooks/update/update_<service>_cts.yml
ansible-playbook playbooks/update_all.yml              # every update playbook, for VMs, CTs and Proxmox nodes
```

Vault secrets live in `vault-file` (password in `password_file`, gitignored); `ansible.cfg` points `inventory=./inventory/` (both the static `.conf` and the dynamic `.py` script are merged) and `vault_password_file=password_file`.

`roles/install_*` are per-service installers (arr, nextcloud, traefik, jumphost, k3s, technitium, etc.) invoked by the `update/update_*_cts.yml` playbooks against the Terraform-sourced inventory groups.

## Network conventions

- `local.courgettes.club` — pre-existing convention used by Traefik/nginx configs and each service's own `*_DOMAIN` env var.
- `actual.courgettes.club` — newer zone, authoritative on dns1/dns2, auto-populated with one A record per Terraform-managed container plus any `technitium_extra_records` entries. Distinct from `local.courgettes.club`; not a replacement for it.
- `proxy.courgettes.club` — public-facing alias for the ISP router; DMZ Traefik terminates TLS for anything CNAMEd to it.
