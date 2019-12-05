#!/bin/bash
set -e

echo "### Adding packages..."
echo "deb http://deb.debian.org/debian buster contrib" >> /etc/apt/sources.list
echo "deb http://deb.debian.org/debian buster-backports main contrib" >> /etc/apt/sources.list
uniq -i /etc/apt/sources.list
apt update
apt install --yes debootstrap gdisk dkms dpkg-dev linux-headers-$(uname -r) efivar
apt install --yes -t buster-backports zfs-dkms
modprobe zfs
mount -t efivarfs efivarfs /sys/firmware/efi/efivars || true
