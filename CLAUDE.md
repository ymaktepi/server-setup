# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository purpose

This is a personal homelab infrastructure repo ("Courgettes Cloud") for a Proxmox cluster split across VLANs (Main/trusted, Entertainment, Guest, Crusted/IoT, DMZ). It has two top-level halves that work together:

- **`tofu/`** — OpenTofu (Terraform) provisions the bare Proxmox LXC containers/VMs.
- **`ansible/`** — Ansible provisions the Proxmox nodes themselves and installs software *inside* the containers/VMs that the OpenTofu stacks create.

**`old/`** is a legacy, no-longer-maintained set of playbooks from before this structure existed — don't extend it.

## The tofu/ansible bridge

`ansible/inventory/inventory.py` is a dynamic Ansible inventory script. It runs `tofu output -json ansible_inventory` in each of `tofu/bootstrap`, `tofu/core`, `tofu/compute` (resolved as `Path(__file__).resolve().parent.parent.parent / "tofu"`, i.e. three levels up from the script, then into the sibling `tofu/` directory) and merges the results into one inventory (grouped by each container's `ansible_groups`, with `ansible_vars` as host vars). This is how Ansible playbooks find hosts that Terraform created — a container only becomes Ansible-reachable once it has a corresponding entry in one of those three `module "containers"` blocks (see `modules/lxc/outputs.tofu`'s `ansible_inventory` output for the exact shape). `ansible/inventory/inventory.conf` separately holds the four Proxmox nodes themselves (`pvenodes` group) plus a few hosts not managed by Terraform at all (`minix`, `gpu`, `infomaniak`).

Since `ansible-playbook` runs this script as its own subprocess (not through `make`'s `sops exec-env` wrapping), it can't inherit AWS credentials for the S3 state backend from anywhere — so the script decrypts `tofu/secrets.enc.yaml` itself (via a direct `sops -d` call) and injects `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` into the `tofu output` subprocess's environment. This means `SOPS_AGE_KEY_FILE` must be exported before running *any* `ansible-playbook`/`ansible-inventory` command, not just ones that touch vault secrets — without it, inventory resolution itself fails.

## tofu/ (OpenTofu stacks)

Three **independent** OpenTofu root modules, each with its own state (Garage/S3-compatible backend, bucket `opentofu-state`, addressed by IP:port rather than hostname to avoid a circular dependency on the DNS this repo itself manages):

- **`bootstrap/`** — self-contained: builds a custom Debian LXC template (debootstraps a rootfs, grafts in the `technitium/dns-server` Docker image's files, installs systemd/networking/ssh) because the `bpg/proxmox` provider's native OCI-container support can't override entrypoint/env vars. Deploys it as `dns1`/`dns2` (Technitium DNS), and owns the `actual.courgettes.club` zone: primary on dns1, secondary (zone transfer) on dns2, Cloudflare DoT forwarders, plus any extra hardcoded records (`var.technitium_extra_records`).
- **`core/`** and **`compute/`** — plain container definitions for other services (Traefik, jumphost, arr stack, Nextcloud, etc.). No special bootstrapping concerns.

All three share **`modules/lxc`**, the reusable container abstraction (`proxmox_virtual_environment_container` + DNS record registration). Its `containers` input is a map keyed by container name; each value's schema is in `modules/lxc/variables.tofu`. Hostnames are derived as `replace(name, "_", "-") + domain_name` (default `domain_name = ".nico"`). DNS names use the same dash-replacement under `actual.courgettes.club` via `technitium_record` resources (the `darkhonor/technitium` provider), gated by `technitium_register_records` and skipped entirely when that's false.

`modules/vms` exists but is currently unused/commented out everywhere.

### Known gotcha: `bootstrap-apply` is 3 stages, not 1

The `darkhonor/technitium` provider unconditionally pings its target server during configuration (no way to disable it), and OpenTofu configures every declared provider whose arguments are statically resolvable regardless of whether any resource's `count`/`for_each` actually uses it — so it can't be configured until dns1/dns2 exist and respond. `make bootstrap-apply` handles this with three `tofu apply` calls using `-exclude` (see the Makefile and the comment above the `provider "technitium"` block in `bootstrap/main.tofu`): containers+tokens first, then the zone/settings (once dns1/dns2 respond), then the actual DNS records. Each stage is a no-op on a routine re-apply. `make bootstrap-destroy` needs the same two API tokens for the same reason.

### Commands

```bash
cd tofu
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"   # secrets come from sops+age, see tofu/README.md — no external app/service needed
make bootstrap-apply     # only stack safe to apply routinely — self-contained 3-stage dance, see above
make bootstrap-destroy
make bootstrap-plan
make core-plan / make core-apply
make compute-plan / make compute-apply
make plan / make apply   # runs all three stacks in sequence
make format              # tofu fmt across all three
make install             # tofu init -upgrade across all three
```

Every target above is wrapped in `$(SOPS_EXEC)` (`sops exec-env secrets.enc.yaml ...`) in the Makefile, which decrypts `tofu/secrets.enc.yaml` into environment variables (`TF_VAR_*`, `AWS_*`) for that one command. `sops exec-env`'s "command to run" must be passed as a single argument — splitting it across multiple argv entries hits a real sops parsing bug (`error: missing file to decrypt`) — which is why every Makefile recipe quotes its command as one string.

`core` and `compute` run this homelab's actual production workloads — don't run `core-apply`/`compute-apply` (or the top-level `make apply`/`make plan`, which chain all three) without the user's explicit go-ahead for that specific action, even though `bootstrap-apply`/`bootstrap-destroy` are fine to run routinely.

## ansible/ (Ansible)

```bash
cd ansible
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"   # same age identity as tofu/'s Terraform secrets
ansible pvenodes -m ping                              # sanity-check connectivity to the 4 Proxmox nodes
ansible-playbook playbooks/pve/pve_onboard.yml -e 'ansible_user=root'   # one-time: create the ansible user on a fresh node
ansible-playbook playbooks/provisioning/build_cts.yml  # create/start/stop LXCs from variable_files/cts (legacy path — most new containers go through tofu/ now)
ansible-playbook playbooks/update/update_<service>_cts.yml
ansible-playbook playbooks/update_all.yml              # every update playbook, for VMs, CTs and Proxmox nodes
```

Secrets live in `inventory/group_vars/all/vault.sops.yaml`, sops-encrypted (same root-level `.sops.yaml`/age recipient as `tofu/secrets.enc.yaml` — one shared config covers both). The `community.sops` vars plugin (enabled via `ansible.cfg`'s `vars_plugins_enabled`) decrypts it transparently at vars-loading time, exactly like the `ansible-vault`-encrypted `vault-file` it replaced — so every role/template still references secrets as plain `{{ variable_name }}`, no `lookup('env', ...)` involved. `ansible.cfg` points `inventory=./inventory/` (both the static `.conf` and the dynamic `.py` script are merged).

`roles/install_*` are per-service installers (arr, nextcloud, traefik, jumphost, k3s, technitium, etc.) invoked by the `update/update_*_cts.yml` playbooks against the Terraform-sourced inventory groups.

## Network conventions

- `local.courgettes.club` — pre-existing convention used by Traefik/nginx configs and each service's own `*_DOMAIN` env var.
- `actual.courgettes.club` — newer zone, authoritative on dns1/dns2, auto-populated with one A record per Terraform-managed container plus any `technitium_extra_records` entries. Distinct from `local.courgettes.club`; not a replacement for it.
- `proxy.courgettes.club` — public-facing alias for the ISP router; DMZ Traefik terminates TLS for anything CNAMEd to it.
