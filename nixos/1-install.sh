#!/usr/bin/env -S bash -e

SCRIPT_DIR="$(cd "$(dirname "$0")" ; pwd)"

HOSTNAME=$1
DEVICE=$2

echo "### Partitioning ${DEVICE}"
parted ${DEVICE} -- mklabel gpt
parted ${DEVICE} -- mkpart primary 512MiB 100%
parted ${DEVICE} -- mkpart ESP fat32 1MiB 512MiB
parted ${DEVICE} -- set 2 esp on

if [ -b ${DEVICE}-part1 ]
then
    ROOT_PARTITION=${DEVICE}-part1
    BOOT_PARTITION=${DEVICE}-part2
elif [ -b ${DEVICE}1 ]
then
    ROOT_PARTITION=${DEVICE}1
    BOOT_PARTITION=${DEVICE}2
else
    echo "Failed to find partitions of ${DEVICE}"
    exit 1
fi

echo "### Formatting root ${ROOT_PARTITION}"
mkfs.ext4 -L nixos ${ROOT_PARTITION}

echo "### Formatting boot ${BOOT_PARTITION}"
mkfs.fat -F 32 -n boot ${BOOT_PARTITION}

echo "### Mounting"
mount ${ROOT_PARTITION} /mnt
mkdir -p /mnt/boot
mount ${BOOT_PARTITION} /mnt/boot

echo "### Copying configuration"
rsync -arP ${SCRIPT_DIR}/${HOSTNAME}/ /mnt
rsync -arP /root/.ssh /mnt/root/
dd bs=1 count=32 if=/dev/urandom of=/mnt/root/vkey
chown -R root:root /mnt

echo "### Generating hardware configuration"
nixos-generate-config --root /mnt

echo "### Installing"
nixos-install --no-root-passwd

echo "### Done! Ready to reboot"
