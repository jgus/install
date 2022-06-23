#!/usr/bin/env -S bash -e

echo "### Formatting boot"
mkfs.fat -F 32 -n boot0 /dev/disk/by-partlabel/boot0
mkdir -p /mnt/boot
mount /dev/disk/by-partlabel/boot0 /mnt/boot

i=1
while [ -b /dev/disk/by-partlabel/boot${i} ]
do
    mkfs.fat -F 32 -n boot${i} /dev/disk/by-partlabel/boot${i}
    mkdir -p /mnt/boot/${i}
    mount /dev/disk/by-partlabel/boot${i} /mnt/boot/${i}
    ((i+=1))
done
