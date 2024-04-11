#!/usr/bin/env bash

set +x

incus launch images:debian/12 unifi
incus exec unifi -- apt-get update
incus exec unifi -- apt-get -y install ca-certificates apt-transport-https gnupg

echo 'deb [ arch=amd64,arm64 ] https://www.ui.com/downloads/unifi/debian stable ubiquiti' > 100-ubnt-unifi.list
incus file push ./100-ubnt-unifi.list unifi/etc/apt/sources.list.d/100-ubnt-unifi.list
curl -fsSL https://dl.ui.com/unifi/unifi-repo.gpg > unifi-repo.gpg
incus file push ./unifi-repo.gpg unifi/etc/apt/trusted.gpg.d/unifi-repo.gpg

echo 'deb [ trusted=yes ] https://repo.mongodb.org/apt/debian bookworm/mongodb-org/7.0 main' > 100-mongodb-org.list
incus file push ./100-mongodb-org.list unifi/etc/apt/sources.list.d/100-mongodb-org.list -pv

curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | gpg --dearmor > mongodb-org.gpg
incus file push ./mongodb-org.gpg unifi/etc/apt/trusted.gpg.d/mongodb-org.gpg -pv

incus exec unifi -- apt-get update
incus exec unifi -- apt-get -y install unifi

incus config set unifi boot.autostart=true
