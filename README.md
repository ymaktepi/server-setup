
# Server setup

0. Setup ssh 
1. `ansible-playbook -i inventory install_packages.yml`
2. `ansible-playbook -i inventory install_nginx_proxy_generator.yml`
   - This might timeout when generating DH parameters. If so, do: `cd /etc/nginx && sudo openssl dhparam -out /etc/nginx/dhparam.pem 4096` 
3. Then any of: 
   - `ansible-playbook -i inventory install_airhorn.yml`
   - `ansible-playbook -i inventory --ask-vault-pass install_courgettes.yml`
   - `ansible-playbook -i inventory --ask-vault-pass install_budget_manager.yml`
   - `ansible-playbook -i inventory --ask-vault-pass install_ctf.yml`
   - `ansible-playbook -i inventory --ask-vault-pass install_steam_network.yml`
   - `ansible-playbook -i inventory install_epic_game_jam.yml`
   - `ansible-playbook -i inventory --ask-vault-pass install_piratefache.yml`

