#!/usr/bin/env -S bash -e

DEVICE=$1

SWAP_SIZE="${SWAP_SIZE:-8GiB}"

echo "### Partitioning ${DEVICE}"
parted ${DEVICE} -- mklabel gpt
parted ${DEVICE} -- mkpart primary 0% "-${BOOT_SIZE}"
parted ${DEVICE} -- name 1 root
parted ${DEVICE} -- mkpart primary "-${BOOT_SIZE}" 100%

while [ ! -b /dev/disk/by-partlabel/root ]
do
    sleep 1
done
