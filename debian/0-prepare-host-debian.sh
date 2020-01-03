#!/bin/bash
set -e

echo "### Adding packages..."
echo "deb http://deb.debian.org/debian buster contrib" >> /etc/apt/sources.list
echo "deb http://deb.debian.org/debian buster-backports main contrib" >> /etc/apt/sources.list
uniq -i /etc/apt/sources.list
apt update
apt install --yes debootstrap gdisk dkms dpkg-dev linux-headers-$(uname -r) efivar zstd ssh
apt install --yes -t buster-backports zfs-dkms
modprobe zfs
mount -t efivarfs efivarfs /sys/firmware/efi/efivars || true

mkdir -p ~/.ssh || true
touch ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
curl https://github.com/jgus.keys >> ~/.ssh/authorized_keys
uniq -i ~/.ssh/authorized_keys
chmod 400 ~/.ssh/authorized_keys

systemctl start ssh
