#!/bin/bash

btrfs subvolume create /var/lib/libvirt/images
btrfs subvolume create /var/lib/libvirt/images/scratch

# TODO: Restore

VIRSH_PACKAGES=(
    qemu qemu-arch-extra
    libvirt virt-manager
    ovmf
    #ebtables
    dnsmasq
    bridge-utils
    openbsd-netcat
)

install "${VIRSH_PACKAGES[@]}"

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
