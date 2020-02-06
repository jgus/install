#!/usr/bin/env bash

set -e

apt -y install cifs-utils smbclient autofs

mkdir -p /beast
/usr/local/bin/beast-shares.sh
cat <<EOF >/etc/auto.master.d/beast.autofs
/- /etc/auto.beast --timeout=300
EOF

service autofs restart
