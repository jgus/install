#!/bin/bash
install samba
mkdir /nas
cat <<EOF >>/etc/fstab

# NAS
EOF
for share in "${NAS_SHARES[@]}"
do
    mkdir /nas/${share}
    echo "//nas/${share} /nas/${share} cifs noauto,nofail,x-systemd.automount,x-systemd.requires=network-online.target,x-systemd.device-timeout=30,credentials=/root/.secrets/nas 0 0" >>/etc/fstab
    mount /nas/${share}
done
