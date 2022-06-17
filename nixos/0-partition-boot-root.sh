#!/usr/bin/env -S bash -e

DEVICE=$1

BOOT_SIZE="${BOOT_SIZE:-512MiB}"

echo "### Partitioning ${DEVICE}"
parted ${DEVICE} -- mklabel gpt
parted ${DEVICE} -- mkpart ESP fat32 1MiB "${BOOT_SIZE}"
parted ${DEVICE} -- set 1 esp on
parted ${DEVICE} -- name 1 boot
parted ${DEVICE} -- mkpart primary "${BOOT_SIZE}" 100%
parted ${DEVICE} -- name 2 root

while [ ! -b /dev/disk/by-partlabel/root ]
do
    sleep 1
done
