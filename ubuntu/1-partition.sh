#!/bin/bash
set -e

HOSTNAME=$1
source "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/config.env

EFI_SIZE=${EFI_SIZE:-+256M}
BOOT_SIZE=${BOOT_SIZE:-+512M}
ROOT_SIZE=${ROOT_SIZE:-0}

echo "### Cleaning up prior partitions..."
umount -Rl /target || true
zpool destroy root || true
for i in /dev/disk/by-label/SWAP*
do
    swapoff "${i}" || true
done

for i in "${!SYSTEM_DEVICES[@]}"
do
    DEVICE="${SYSTEM_DEVICES[$i]}"
    echo "### Wiping and re-partitioning ${DEVICE}..."
    sgdisk --zap-all "${DEVICE}"
    while [ -L "${DEVICE}-part2" ] ; do : ; done
    sgdisk -n1:1M:${EFI_SIZE} -t1:EF00 "${DEVICE}"
    sgdisk -n2:0:${BOOT_SIZE} -t2:8300 "${DEVICE}"
    sgdisk -n3:0:${ROOT_SIZE} -t3:BF00 "${DEVICE}"
    if [[ "${ROOT_SIZE}" != "0" ]]
    then
        sgdisk -n4:0:0 -t4:8200 "${DEVICE}"
    fi
    BOOT_DEVS+=("${DEVICE}-part2")
    ROOT_DEVS+=("${DEVICE}-part3")
    SWAP_DEVS+=("${DEVICE}-part4")
done
sleep 1

# "$(cd "$(dirname "$0")" ; pwd)"/1.1-format-bulk.sh "${HOSTNAME}"
"$(cd "$(dirname "$0")" ; pwd)"/1.1-format-swap.sh "${HOSTNAME}"

echo "### Done partitioning!"
