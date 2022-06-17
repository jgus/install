#!/usr/bin/env -S bash -e

echo "### Formatting boot"
mkfs.fat -F 32 -n boot /dev/disk/by-partlabel/boot
mkdir -p /mnt/boot
mount /dev/disk/by-partlabel/boot /mnt/boot
