#!/usr/bin/env -S bash -e

echo "### Formatting boot"
mkfs.fat -F 32 -n boot /dev/disk/by-partlabel/boot
mkdir -p /mnt/boot
mount /dev/disk/by-partlabel/boot /mnt/boot
if [ -f /boot/vkey ]
then
    cp /boot/vkey /mnt/boot/vkey
else
     dd bs=1 count=32 if=/dev/urandom of=/mnt/boot/vkey
fi