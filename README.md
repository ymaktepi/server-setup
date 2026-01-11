# Courgettes Cloud Infra + Guest Manual

## Infra

The network is split into VLANs.

### Main VLAN

Contains trusted things like laptops, desktops, phones, printer, NAS, PI, Proxmox. Can access every other network.

### Entertainment VLAN

Contains devices like TVs, sound bars, Chromecast. Can be accessed from guest network.

### Guest VLAN

Guests can connect here. Can access entertainment stuff.

### Crusted VLAN

Contains devices like IoT shit, smart things. Can only connect to internet.

### DMZ VLAN

Contains websites and services that can be accessed from the internet.
HTTP(S) and game ports are forwarded from the ISP router.

The DMZ VLAN is as follows:
![infra image](docs-images/infra-courgettes-cloud.png)

#### HTTP(S)

The HTTP(S) ports are forwarded from the ISP router to the Traefik DMZ instance. `proxy.courgettes.club` is an alias for
the actual IP of the ISP router, making it effectively the public facing domain name for the Traefik DMZ instance. Any
new public domain wants to route to a DMZ website must CNAME to `proxy.courgettes.club`, or use ddclient (for root
domains).
In the end, DMZ Traefik listens to any traffic on port 80 and 443 of `proxy.courgettes.club` This effectively allows the
Traefik VM to generate LetsEncrypt certs for domains that are `CNAME`d to `proxy.courgettes.club`.

The Websites VMs have a self-signed certificate that is trusted by the Traefik VM for inside-VLAN communication.
The `install_nginx` ansible role handles the creation of the self-signed certs for all hosts needing one.

#### SSH

A `jumphost` VM is spawned in the VLAN as well. Port 22222 from the ISP router is forwarded to it. A `jumphost` user on
the VM is provisioned as well. It is not allowed to run shell, and can only proxy to other hosts in the VLAN.
See [guest manual](#guest-manual) for details. New users need access to the `jumphost` via SSH key, as well as to their
target VMs. Since shell is not available on the jump host, adding their SSH key to the `jumphost` user's config is fine,
and actual access control happens on the VMs themselves.

### Tailscale

Tailscale is installed in an LXC in the Main VLAN, configured as an exit node. It's using userspace network routing (
i.e. so you don't have to change the default settings for LXCs), publishes all the subnet routes in there (so that you
can access all resources if you have access to Tailscale), and has keys expiry disabled - as expected for headless
servers. See details in the [`install_tailscale_exit_node` role](proxmox/roles/install_tailscale_exit_node).

## Guest Manual

### Getting a new box

Ask the admin to create a new box. Parameters include:

- Number of CPU
- RAM size
- SSD size (for base drive). Defaults to 4.
- Backed up/replicated HDD size (for data, will be mounted to `/mnt/mounted-raid`)

If it's the first time you ask for a box, sned pulbic shs kye.

### Connecting to a box

Your box will be deployed in the `10.10.5.0/24` network. To access it, use the following ssh config:

```
host jumphost
    hostname proxy.courgettes.club
    user jumper
    port 2222

host mybox
    ProxyJump jumphost
    hostname 10.10.5.<IP>
    user root
```

> Note: all vms have fail2ban installed, don't fuck up the ssh config or you'll get soft banned.

### Network access

Your box has unrestricted outbound internet access.

Regarding inbound internet:

- If you need to publish one or more websites:
    - `CNAME` your domain to `proxy.courgettes.club`
    - Ask for a base `nginx` config with self-signed certs to be installed.
    - Add your nginx reverse proxy config for each one of the websites.
        - A sample can be found in `proxmox/roles/install_websites_cts/templates/nginx-reverse-proxy.conf`.
        - You only need to map the HTTPS service to your website.
    - Add config to `proxmox/roles/install_traefik_cts/templates/dmz-config.yml`
        - This will both map your domain to your website but also create a letsencrypt cert for it.
        - In this config you can also configure things like http->https redirections, www.domain.com to domain.com
          redirections, mapping multiple domains to the same website, ...
    - Ask for the traefik config to be redeployed. This is not really a piece that should be re-run often so the
      dependency to admin access should be OK.
- If you want to have custom ports mapped to your machine (i.e. game server):
    - Ask for a new port forwarding.