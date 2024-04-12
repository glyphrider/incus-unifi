#!/usr/bin/env bash

P12_PASS="temppass"

CA_ALIAS="marisol"
UNIFI_KEYSTORE_PASS="aircontrolenterprise"

set -x

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

# SSL Setup for unifi

if [ -f ./unifi.key -a -f ./unifi.crt ]; then
openssl pkcs12 -export -in unifi.crt -inkey unifi.key -out unifi.p12 -name unifi -CAfile ca.crt -caname marisol -passout "pass:$P12_PASS"
fi

if [ -f ./ca.crt ]; then
incus file push ./ca.crt unifi/tmp/ca.crt -pv
incus exec unifi -- keytool -import -trustcacerts -alias "$CA_ALIAS" -file /tmp/ca.crt -keystore /var/lib/unifi/keystore -storepass "$UNIFI_KEYSTORE_PASS" -noprompt
fi

if [ -f ./unifi.p12 ]; then
incus file push ./unifi.p12 unifi/tmp/unifi.p12 -pv
incus exec unifi -- keytool -importkeystore -deststorepass "$UNIFI_KEYSTORE_PASS" -destkeypass "$UNIFI_KEYSTORE_PASS" -destkeystore /var/lib/unifi/keystore -srckeystore /tmp/unifi.p12 -srcstoretype PKCS12 -srcstorepass "$P12_PASS" -alias unifi -noprompt

# Move SSL port to 443
incus exec unifi -- sed -i 's/\(# \|\)unifi\.https\.port\=.*/unifi.https.port=443/' /var/lib/unifi/system.properties
incus exec unifi -- bash -c 'setcap CAP_NET_BIND_SERVICE=+eip $(readlink -f /usr/bin/java)'
incus exec unifi -- systemctl restart unifi
fi
