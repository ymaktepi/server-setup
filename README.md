
# Server setup

1. `ansible-playbook -i inventory install_packages.yml`
2. `ansible-playbook -i inventory install_nginx_proxy_generator.yml`
3. Then
  - `ansible-playbook -i inventory install_airhorn.yml`
  - `ansible-playbook -i inventory install_ctf.yml`

