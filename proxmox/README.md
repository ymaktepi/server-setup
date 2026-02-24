# Proxmox Ansible setup scripts

Following tutorials [here](https://www.techtutorials.tv/sections/promox/proxmox-how-to-automate-using-ansible/)
and [here](https://www.techtutorials.tv/sections/promox/automate-vm-creation-on-proxmox-with-ansible/)

## Update everything

```bash
ansible all -m apt -a "upgrade=yes update_cache=yes cache_valid_time=86400" --become
```

## Password management

Put the vault password inside `password_file`.

## Inventory

Only contains the proxmox host for now.

## Playbooks

### Root

- `update_all.yml` - Runs all update playbooks in sequence

### pve/ - Proxmox host management

- `pve/pve_onboard.yml` - Initial Proxmox setup (installs sudo, creates ansible user, adds SSH key)
- `pve/pve_mounts.yml` - Configure CIFS mounts for LXC shares
- `pve/update_pve.yml` - Update Proxmox packages and install dependencies

### provisioning/ - VM and container creation

- `provisioning/build_vms.yml` - Create VMs from cloud-init images
- `provisioning/build_cts.yml` - Create LXC containers
- `provisioning/add_ssh_key_to_host.yml` - Copy SSH key to hosts

> Note: when running `build_*` playbooks, we currently need to:
> - Create a new entry in the vm or ct list, `state: new`.
> - Run the `build_*` playbook, which _creates_ the vm/ct.
> - Set the state to `started`.
> - Run the playbook again, which _starts_ the vm/ct.

### update/ - Update specific containers

- `update/update_arr.yml` - Update ARR stack containers (Sonarr, Radarr, etc.)
- `update/update_gpu.yml` - Update GPU-related containers
- `update/update_infomaniak.yml` - Update Infomaniak containers
- `update/update_jumphost_cts.yml` - Update Jumphost container
- `update/update_k3s.yml` - Update K3s cluster
- `update/update_minix.yml` - Update Minix container
- `update/update_networkcheckers_cts.yml` - Update Network Checkers container
- `update/update_nextcloud.yml` - Update Nextcloud container
- `update/update_other_cts.yml` - Update other miscellaneous containers
- `update/update_rsync_backup_cts.yml` - Update Rsync backup container
- `update/update_traefik_cts.yml` - Update Traefik container
- `update/update_uptimekuma_cts.yml` - Update Uptime Kuma container

## Preparing Proxmox

### Base proxmox onboarding: `pve/pve_onboard.yml`

- Installs sudo
- Creates an ansible user, sets ssh key (from default ssh key in home folder), adds it to sudoers (via
  the `files/sudoers_ansible` local file).

To run it:

```bash
ansible-playbook playbooks/pve/pve_onboard.yml -e 'ansible_user=root'
```

To test the key was moved and that you can connect using the ansible user:

```bash
# note: the ansible user is set in the inventory file
ansible pvenodes -m ping
```

- Create a new user in the UI, name: `ansible`, rest is default.
- In Datacenter -> Permissions, hit "Add->User Permissions", select '/' and the `ansible` user, map it to admin.
- Create an API Token in the UI, for the `ansible` user. Uncheck privilege separation.

> Note: how to add zfs support for isos folder  
> `zfs create hdd-8tb-raid/isos`  
> `zfs set compression=zstd hdd-8tb-raid/isos`  
> `zfs set relatime=on hdd-8tb-raid/isos`  
> `pvesm add dir isos --content iso --is_mountpoint  yes --shared 0 --path "/hdd-8tb-raid/isos/"`
> you may want to add other types than just iso above

Open the vault:

```bash
ansible-vault create vault-file
```

Write down your secrets inside the vault:

```yaml
api_user: ansible@pam
api_token_name: ansible-token
api_token: whatever
```

To edit the vault:

```bash
ansible-vault edit --vault-password-file password_file vault-file
```

### Update Proxmox: `pve/update_pve.yml`

Update packages and install dependencies in Proxmox.

```bash
ansible-playbook playbooks/pve/update_pve.yml
```

### Mounts: `pve/pve_mounts.yml`

Configure CIFS mounts for LXC shares.

```bash
ansible-playbook playbooks/pve/pve_mounts.yml
```

### Build VMs: `provisioning/build_vms.yml`

```bash
ansible-playbook playbooks/provisioning/build_vms.yml
```

### Build Containers: `provisioning/build_cts.yml`

```bash
ansible-playbook playbooks/provisioning/build_cts.yml
```

Also used to delete/start/stop cts. To do so, change the state in the variable_files/cts.

### Update Containers: `update/update_*_cts.yml`

```bash
ansible-playbook playbooks/update/update_uptimekuma_cts.yml
## you then need to import the backup json file to have all the uptime checkers up.
```

```bash
ansible-playbook playbooks/update/update_networkcheckers_cts.yml
```

```bash
ansible-playbook playbooks/update/update_traefik_cts.yml
```

```bash
ansible-playbook playbooks/update/update_jumphost_cts.yml
```

### Update all: `update_all.yml`

Run all update playbooks in sequence, for VMs, CTs **and** Proxmox nodes.

```bash
ansible-playbook playbooks/update_all.yml
```

## Jumphost config

To grant access to other users, a jumphost service is put in place. It can _only_ be used as a jump proxy to reach
other VMs. You can either do `ssh -J jumper@jumphost user@targethost`, or use the following config:

```conf
Host targethost
    ProxyJump jumphost
    HostName <target-hostname>
    User <target-user>

Host jumphost
    HostName <jumphost-hostname>
    User jumper
```

### Add ssh key to host

Put pub key in `files` folder then:

```bash
ansible-playbook playbooks/provisioning/add_ssh_key_to_host.yml -e '{"ssh_copy_hosts": "traefik_default:networkcheckers:uptimekuma", "ssh_copy_user": "root", "ssh_copy_filename": "key-name.pub"}'
```
