#!/usr/bin/env -S bash -e

echo "### Formatting root as ext4"
mkfs.ext4 -L root /dev/disk/by-partlabel/root
mount /dev/disk/by-partlabel/root /mnt
