#!/bin/bash
set -e

HOSTNAME=$1
source "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/config.env

HAS_UEFI=${HAS_UEFI:-1}
EFI_SIZE=${EFI_SIZE:-+256M}
BOOT_SIZE=${BOOT_SIZE:-+512M}
ROOT_SIZE=${ROOT_SIZE:-0}
SWAP_SIZE=${SWAP_SIZE:-0}

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
    if ((HAS_UEFI))
    then
        sgdisk --zap-all "${DEVICE}"
    else
        parted ${DEVICE} mklabel msdos
    fi
    while [ -L "${DEVICE}-part2" ] ; do : ; done
    if ((HAS_UEFI))
    then
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
    else
        parted ${DEVICE} mkpart primary ext4 2MiB ${BOOT_SIZE}
        parted ${DEVICE} mkpart primary zfs ${BOOT_SIZE} ${ROOT_SIZE}
        parted ${DEVICE} mkpart primary linux-swap ${ROOT_SIZE} ${SWAP_SIZE}
        parted ${DEVICE} mkpart extended zfs ${SWAP_SIZE} 100%
        BOOT_DEVS+=("${DEVICE}-part1")
        ROOT_DEVS+=("${DEVICE}-part2")
        SWAP_DEVS+=("${DEVICE}-part3")
    fi
done
sleep 1

# "$(cd "$(dirname "$0")" ; pwd)"/1.1-format-bulk.sh "${HOSTNAME}"
"$(cd "$(dirname "$0")" ; pwd)"/1.1-format-swap.sh "${HOSTNAME}"

echo "### Done partitioning!"
