#!/bin/bash

lvcreate -n images          -V 1T --thinpool tp vg
lvcreate -n images-scratch  -V 1T --thinpool tp vg
mkfs.ext4 /dev/vg/images
mkfs.ext4 /dev/vg/images-scratch
mkdir -p /var/lib/libvirt/images
mount -o discard /dev/vg/images /var/lib/libvirt/images
mkdir -p /var/lib/libvirt/images/scratch
mount -o discard /dev/vg/images-scratch /var/lib/libvirt/images/scratch
cat <<EOF >>/etc/fstab

# libvirt
/dev/vg/images          /var/lib/libvirt/images            ext4    rw,relatime,discard,stripe=16   0   2
/dev/vg/images-scratch  /var/lib/libvirt/images/scratch    ext4    rw,relatime,discard,stripe=16   0   2
EOF

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
