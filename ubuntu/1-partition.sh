#!/bin/bash
set -e

HOSTNAME=$1
source "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/config.env

HAS_UEFI=${HAS_UEFI:-1}
MBR_GAP="2MiB"
if ((HAS_UEFI))
then
    EFI_END=${EFI_END:-256MiB}
    BOOT_END=${BOOT_END:-768MiB}
else
    EFI_END=${MBR_GAP}
    BOOT_END=${BOOT_END:-512MiB}
fi
ROOT_END=${ROOT_END:--16GiB}
SWAP_END=${SWAP_END:-100%}

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
        parted ${DEVICE} mklabel gpt
    else
        parted ${DEVICE} mklabel msdos
    fi
    while [ -L "${DEVICE}-part2" ] ; do : ; done
    
    p=1

    if [[ "${MBR_GAP}" != "${EFI_END}" ]]
    then
        parted ${DEVICE} mkpart primary fat32 ${MBR_GAP} ${EFI_END}
        parted name ${p} ${HOSTNAME}_EFI_${i}
        ((++p))
    fi

    parted ${DEVICE} mkpart primary zfs ${EFI_END} ${BOOT_END}
    parted name ${p} ${HOSTNAME}_BOOT_${i}
    ((++p))

    parted ${DEVICE} mkpart primary zfs ${BOOT_END} ${ROOT_END}
    parted name ${p} ${HOSTNAME}_ROOT_${i}
    ((++p))

    if [[ "${ROOT_END}" != "${SWAP_END}" ]]
    then
        parted ${DEVICE} mkpart primary linux-swap ${ROOT_END} ${SWAP_END}
        parted name ${p} ${HOSTNAME}_SWAP_${i}
        ((++p))
    fi

    if [[ "${SWAP_END}" != "100%" ]]
    then
        parted ${DEVICE} mkpart extended zfs ${SWAP_END} 100%
        parted name ${p} ${HOSTNAME}_EXT_${i}
        ((++p))
    fi



        SWAP_DEVS+=("${DEVICE}-part3")
done
sleep 1

# "$(cd "$(dirname "$0")" ; pwd)"/1.1-format-bulk.sh "${HOSTNAME}"
"$(cd "$(dirname "$0")" ; pwd)"/1.1-format-swap.sh "${HOSTNAME}"

echo "### Done partitioning!"
