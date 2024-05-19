# Proxmox Ansible setup scripts

Following tutorials [here](https://www.techtutorials.tv/sections/promox/proxmox-how-to-automate-using-ansible/)
and [here](https://www.techtutorials.tv/sections/promox/automate-vm-creation-on-proxmox-with-ansible/)

## Password management

Put the vault password inside `password_file`.

## Inventory

Only contains the proxmox host for now.

## Preparing Proxmox

### Base proxmox onboarding: `pve_onboard.yml`

- Installs sudo
- Creates an ansible user, sets ssh key (from default ssh key in home folder), adds it to sudoers (via
  the `files/sudoers_ansible` local file).

To run it:

```bash
ansible-playbook pve_onboard.yml --user=root
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

### Update apt packages: `pve_packages.yml`

Install and update packages in proxmox.

```bash
ansible-playbook pve_packages.yml
```

### Spawn dumb LXC: `dumb_container.yml`

Clones the VM 101 and starts it:

```bash
ansible-playbook dumb_container.yml
```

### Build VMs: `build_vms.yml`

```bash
ansible-playbook build_vms.yml
```
### Build Containers: `build_cts.yml`

```bash
ansible-playbook build_cts.yml
```

Also used to delete/start/stop cts. To do so, change the state in the variable_files/cts.

### Update Containers: `update_*_cts.yml`

```bash
ansible-playbook update_uptimekuma_cts.yml
## you then need to import the backup json file to have all the uptime checkers up.
```
```bash
ansible-playbook update_networkcheckers_cts.yml
```
