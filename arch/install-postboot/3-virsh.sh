#!/bin/bash
if which virsh
then
    echo "### Configuring KVM..."
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
fi
