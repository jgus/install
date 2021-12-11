#!/bin/bash -e

source "$(cd "$(dirname "$0")" ; pwd)"/common.sh "$@"

MBR_GAP=2MiB
if ((HAS_UEFI))
then
    EFI_END=${EFI_END:-512MiB}
    BOOT_END=${BOOT_END:-8192MiB}
    SWAP_END=${SWAP_END:-40960MiB}
else
    EFI_END=4MiB
    BOOT_END=${BOOT_END:-8192MiB}
    SWAP_END=${SWAP_END:-40960MiB}
fi
ROOT_END=${ROOT_END:-100%}

echo "### Cleaning up prior partitions..."
umount -Rl /target || true
zpool destroy bpool || true
zpool destroy rpool || true
for i in $(swapon --show=NAME --noheadings)
do
    swapoff "${i}" || true
done
for i in $(cd /dev/mapper; ls ${HOSTNAME}-swap-*)
do
    cryptsetup close "${i}" || true
done

EFI_IDS=()
BOOT_IDS=()
ROOT_IDS=()
SWAP_IDS=()
EXT_IDS=()
for i in "${!SYSTEM_DEVICES[@]}"
do
    DEVICE="${SYSTEM_DEVICES[$i]}"
    echo "### Wiping and re-partitioning ${DEVICE}..."
    blkdiscard "${DEVICE}" || true
    parted ${DEVICE} -- mklabel gpt
    sleep 2
    
    p=1

    if ((HAS_UEFI))
    then
        echo "### Creating EFI partition ${p} on ${DEVICE}..."
        timeout -k 15 10 bash -c -- "while ! parted ${DEVICE} -- mkpart efi${i} fat32 ${MBR_GAP} ${EFI_END}; do sleep 1; done"
        sleep 1
        EFI_IDS+=($(blkid ${DEVICE}-part${p} -o value -s PARTUUID))
        ((++p))
    else
        echo "### Creating GRUB BOOT partition ${p} on ${DEVICE}..."
        timeout -k 15 10 bash -c -- "while ! parted ${DEVICE} -- mkpart grub${i} fat32 ${MBR_GAP} ${EFI_END}; do sleep 1; done"
        parted ${DEVICE} -- set ${p} bios_grub on
        sleep 1
        ((++p))
    fi

    echo "### Creating BOOT partition ${p} on ${DEVICE}..."
    timeout -k 15 10 bash -c -- "while ! parted ${DEVICE} -- mkpart boot${i} zfs ${EFI_END} ${BOOT_END}; do sleep 1; done"
    sleep 1
    BOOT_IDS+=($(blkid ${DEVICE}-part${p} -o value -s PARTUUID))
    ((++p))

    if [[ "${BOOT_END}" != "${SWAP_END}" ]]
    then
        echo "### Creating SWAP partition ${p} on ${DEVICE}..."
        timeout -k 15 10 bash -c -- "while ! parted ${DEVICE} -- mkpart swap${i} linux-swap ${BOOT_END} ${SWAP_END}; do sleep 1; done"
        sleep 1
        SWAP_IDS+=($(blkid ${DEVICE}-part${p} -o value -s PARTUUID))
        ((++p))
    fi

    echo "### Creating ROOT partition ${p} on ${DEVICE}..."
    timeout -k 15 10 bash -c -- "while ! parted ${DEVICE} -- mkpart root${i} zfs ${SWAP_END} ${ROOT_END}; do sleep 1; done"
    sleep 1
    ROOT_IDS+=($(blkid ${DEVICE}-part${p} -o value -s PARTUUID))
    ((++p))

    if [[ "${ROOT_END}" != "100%" ]]
    then
        echo "### Creating EXT partition ${p} on ${DEVICE}..."
        timeout -k 15 10 bash -c -- "while ! parted ${DEVICE} -- mkpart extended${i} ${ROOT_END} 100%; do sleep 1; done"
        sleep 1
        EXT_IDS+=($(blkid ${DEVICE}-part${p} -o value -s PARTUUID))
        ((++p))
    fi
done
cat >/tmp/partids << EOF
EFI_IDS=(${EFI_IDS[@]})
BOOT_IDS=(${BOOT_IDS[@]})
ROOT_IDS=(${ROOT_IDS[@]})
SWAP_IDS=(${SWAP_IDS[@]})
EXT_IDS=(${EXT_IDS[@]})
EOF
sleep 1

# "$(cd "$(dirname "$0")" ; pwd)"/1.1-format-bulk.sh "$@"
"$(cd "$(dirname "$0")" ; pwd)"/1.1-format-swap.sh "$@"

echo "### Done partitioning!"
