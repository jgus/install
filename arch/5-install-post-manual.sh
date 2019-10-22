#!/bin/bash
set -e

HOSTNAME=$(hostname)
source "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/config.env

echo "### Adding other users..."
for U in "${OTHER_USERS[@]}"
do
    u=$(echo "${U}" | awk '{print tolower($0)}')
    useradd --groups gustafson --user-group --no-create-home "${u}"
    cat <<EOF | passwd "${u}"
changeme
changeme
EOF
    passwd -e "${u}"
done

rm -rf /install
