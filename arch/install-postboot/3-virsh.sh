#!/bin/bash
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
