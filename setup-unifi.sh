#!/usr/bin/env bash

CONTAINER_NAME=unifi-trixie

P12_PASS="temppass"

CA_ALIAS="marisol"
UNIFI_KEYSTORE_PASS="aircontrolenterprise"

set -x

incus stop $CONTAINER_NAME
incus delete $CONTAINER_NAME

incus launch images:debian/13 $CONTAINER_NAME
incus exec $CONTAINER_NAME -- apt-get update
incus exec $CONTAINER_NAME -- apt-get -y install ca-certificates apt-transport-https gnupg

echo 'deb [ arch=amd64,arm64 ] https://www.ui.com/downloads/unifi/debian stable ubiquiti' > 100-ubnt-unifi.list
incus file push ./100-ubnt-unifi.list $CONTAINER_NAME/etc/apt/sources.list.d/100-ubnt-unifi.list
curl -fsSL https://dl.ui.com/unifi/unifi-repo.gpg > unifi-repo.gpg
incus file push ./unifi-repo.gpg $CONTAINER_NAME/etc/apt/trusted.gpg.d/unifi-repo.gpg

echo 'deb [ trusted=yes ] https://repo.mongodb.org/apt/debian bookworm/mongodb-org/8.0 main' > 100-mongodb-org.list
incus file push ./100-mongodb-org.list $CONTAINER_NAME/etc/apt/sources.list.d/100-mongodb-org.list -pv

curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc | gpg --dearmor > mongodb-org.gpg
incus file push ./mongodb-org.gpg $CONTAINER_NAME/etc/apt/trusted.gpg.d/mongodb-org.gpg -pv

incus exec $CONTAINER_NAME -- apt-get update
incus exec $CONTAINER_NAME -- apt-get -y install unifi

incus config set $CONTAINER_NAME boot.autostart=true

# incus profile create bridged
# incus profile device add bridged eth0 nic nictype=bridged parent=br0
incus profile add $CONTAINER_NAME bridged
incus config device override $CONTAINER_NAME eth0 hwaddr='00:16:3e:cd:e9:6d'
incus restart $CONTAINER_NAME

# SSL Setup for unifi

if [ -f ./unifi.key -a -f ./unifi.crt ]; then
openssl pkcs12 -export -in unifi.crt -inkey unifi.key -out unifi.p12 -name unifi -CAfile ca.crt -caname marisol -passout "pass:$P12_PASS"
fi

if [ -f ./ca.crt ]; then
incus file push ./ca.crt $CONTAINER_NAME/tmp/ca.crt -pv
incus exec $CONTAINER_NAME -- keytool -import -trustcacerts -alias "$CA_ALIAS" -file /tmp/ca.crt -keystore /var/lib/unifi/keystore -storepass "$UNIFI_KEYSTORE_PASS" -noprompt
fi

if [ -f ./unifi.p12 ]; then
incus file push ./unifi.p12 $CONTAINER_NAME/tmp/unifi.p12 -pv
incus exec $CONTAINER_NAME -- keytool -importkeystore -deststorepass "$UNIFI_KEYSTORE_PASS" -destkeypass "$UNIFI_KEYSTORE_PASS" -destkeystore /var/lib/unifi/keystore -srckeystore /tmp/unifi.p12 -srcstoretype PKCS12 -srcstorepass "$P12_PASS" -alias unifi -noprompt

# Move SSL port to 443
incus exec $CONTAINER_NAME -- sed -i 's/\(# \|\)unifi\.https\.port\=.*/unifi.https.port=443/' /var/lib/unifi/system.properties
incus exec $CONTAINER_NAME -- bash -c 'setcap CAP_NET_BIND_SERVICE=+eip $(readlink -f /usr/bin/java)'
incus exec $CONTAINER_NAME -- systemctl restart unifi
fi
