# Openstack
## Init
Documentation : [Quick Guide - Infomaniak Openstack Public Cloud Guide](https://docs.infomaniak.cloud/user-guide/0005.quickguide/)

Installer openstack client
`brew install openstackclient`

Télécharger le fichier openrc depuis l’interface d’infomaniak
`source ~/Downloads/PCP-3FDXPZC-openrc.sh`

Créer une keypair
`openstack keypair create --public-key ~/.ssh/id_rsa.pub cara_pair`

Créer un network / routeur / subnet
```
openstack network create our-network
openstack subnet create our-subnet --network our-network --dhcp --subnet-range 10.10.10.0/24 --dns-nameserver 83.166.143.51 --dns-nameserver 83.166.143.52 --allocation-pool start=10.10.10.100,end=10.10.10.200
openstack network list --external | grep floating
openstack floating ip create ext-floating1
openstack router create our-router
openstack router set --external-gateway ext-floating1 our-router
openstack router add subnet our-router our-subnet
```

Créer la VM
`openstack server create --key-name cara_pair --flavor a2-ram4-disk50-perf1 --network our-network --image "Debian 11.2 bullseye" our-prod-vm`

Lier la floating ip au port de la VM
```
openstack floating ip set --port 76e41c60-50ae-4d72-bb31-d471b42364e9 195.15.247.199

76e41c60-50ae-4d72-bb31-d471b42364e9 : depuis l'interface -> VM -> Interfaces -> Cliquer sur le nom du port
195.15.247.199 : Floating IP
```

Authoriser le port SSH
`openstack security group rule create --ingress --protocol tcp --dst-port 22 --ethertype IPv4 default`

Se connecter à la machine
`ssh debian@195.15.247.199`



#openstack