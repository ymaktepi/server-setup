#! /usr/bin/env bash

# files to keep in ./data:
# password-file query_ip_* ts3server.sqlitedb

# down
docker compose down

# accept license for new version of TS
sudo touch data/.ts3server_license_accepted

# update version
docker compose pull

# up again
docker compose up -d