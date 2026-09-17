# Garage S3 Storage for OpenTofu

Garage runs on the Synology DS224+ via Docker/Container Manager and provides S3-compatible storage for OpenTofu/Terraform state.

The Docker Compose file and `garage.toml` are kept alongside this README.

## Purpose

* Store OpenTofu state remotely instead of locally or in Git.
* Keep state independent of the Proxmox cluster.
* Use Garage's S3 API as the OpenTofu backend.
* Use native OpenTofu state locking with `use_lockfile = true`.
* Keep Garage data on persistent Synology storage.
* Back up the Garage data using the Synology backup/snapshot strategy.

## Garage setup

Garage is configured as a **single-node deployment**.

The node:

* Hostname: `synology-8`
* Node ID: `9d561c488a2ebde0`
* Zone: `synology-8`
* Assigned capacity: `10G`

The 10 GB capacity is more than enough for OpenTofu state.

## Useful commands

A shell alias is configured:

```bash
alias garage="sudo docker exec garage /garage"
```

Check the node:

```bash
garage status
```

Show the current layout:

```bash
garage layout show
```

Assign the node to the layout:

```bash
garage layout assign -z synology-8 -c 10G 9d561c488a2ebde0
```

Apply a layout:

```bash
garage layout apply --version 1
```

## OpenTofu bucket

Create a dedicated bucket:

```bash
garage bucket create opentofu-state
```

Create a dedicated access key:

```bash
garage key create opentofu
```

Grant the key access to the state bucket:

```bash
garage bucket allow \
  --read \
  --write \
  --owner \
  opentofu-state \
  --key opentofu
```

Store the generated access key and secret in 1Password. Do not commit them to Git.

## OpenTofu backend

The OpenTofu backend should use the Garage S3 endpoint and native state locking:

```hcl
terraform {
  backend "s3" {
    # ...
  }
}
```

Credentials should be provided through environment variables or 1Password rather than stored in the OpenTofu configuration.
Use `make login`.

## Network / TLS

Garage's S3 API is exposed through DSM reverse proxy rather than directly to the network.

Planned flow:

```text
OpenTofu
   |
   | HTTPS
   v
nas-1.nico (set in router)
   |
   v
DSM Reverse proxy
   |
   | HTTP
   v
Synology Garage :3900
```

### Create the reverse proxy

On DSM:

Control Panel → Login Portal → Advanced → Reverse Proxy → Create

- Source
```
Protocol: HTTPS
Hostname: nas-2.nico
Port: 443
```
- Destination
```
Protocol: HTTP
Hostname: 127.0.0.1
Port: 3900
```
