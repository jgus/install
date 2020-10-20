#!/bin/bash

source /usr/local/bin/functions.sh
for v in $(ssh root@jarvis.gustafson.me zfs list -r -o name -H e/$(hostname)/z/images | sed "s.e/$(hostname)/..")
do
    zfs_send_new_snapshots root@jarvis.gustafson.me e/$(hostname)/${v} "" ${v}
done

zfs create -o mountpoint=/var/lib/libvirt/images -o com.sun:auto-snapshot=true z/images || zfs set mountpoint=/var/lib/libvirt/images com.sun:auto-snapshot=true z/images
zfs create -o com.sun:auto-snapshot=false z/images/scratch || zfs set com.sun:auto-snapshot=false z/images/scratch

install qemu qemu-arch-extra libvirt ebtables dnsmasq bridge-utils openbsd-netcat virt-manager ovmf
systemctl enable --now libvirtd.service
if [[ -f "$(cd "$(dirname "$0")" ; pwd)/${HOSTNAME}/libvirt/internal-network.xml" ]]
then
    virsh net-define "$(cd "$(dirname "$0")" ; pwd)/${HOSTNAME}/libvirt/internal-network.xml"
    virsh net-autostart internal
    virsh net-start internal
fi
cat << EOF >> /etc/libvirt/qemu.conf
nvram = [
"/usr/share/ovmf/x64/OVMF_CODE.fd:/usr/share/ovmf/x64/OVMF_VARS.fd"
]
EOF

usermod -a -G libvirt josh
mkdir -p /home/josh/.config/libvirt
echo 'uri_default = "qemu:///system"' >> /home/josh/.config/libvirt/libvirt.conf
chown -R josh:josh /home/josh
