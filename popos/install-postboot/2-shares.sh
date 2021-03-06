#!/bin/bash
install cifs-utils smbclient
mkdir /nas
cat <<EOF >>/etc/fstab

# NAS
EOF
for share in "${NAS_SHARES[@]}"
do
    mkdir /nas/${share}
    echo "//nas.gustafson.me/${share} /nas/${share} cifs noauto,nofail,x-systemd.automount,x-systemd.requires=network-online.target,x-systemd.device-timeout=30,credentials=/root/.secrets/nas 0 0" >>/etc/fstab
    mount /nas/${share}
done
