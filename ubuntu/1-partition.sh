#!/bin/bash -e

source "$(cd "$(dirname "$0")" ; pwd)"/common.sh "$@"

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
zpool destroy boot || true
zpool destroy root || true
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
    if ((HAS_UEFI))
    then
        parted ${DEVICE} -- mklabel gpt
    else
        parted ${DEVICE} -- mklabel msdos
    fi
    sleep 2
    
    p=1

    if [[ "${MBR_GAP}" != "${EFI_END}" ]]
    then
        echo "### Creating EFI partition ${p} on ${DEVICE}..."
        timeout -k 15 10 bash -c -- "while ! parted ${DEVICE} -- mkpart primary fat32 ${MBR_GAP} ${EFI_END}; do sleep 1; done"
        EFI_IDS+=($(blkid ${DEVICE}-part${p} -o value -s PARTUUID))
        ((++p))
    fi

    echo "### Creating BOOT partition ${p} on ${DEVICE}..."
    timeout -k 15 10 bash -c -- "while ! parted ${DEVICE} -- mkpart primary zfs ${EFI_END} ${BOOT_END}; do sleep 1; done"
    BOOT_IDS+=($(blkid ${DEVICE}-part${p} -o value -s PARTUUID))
    ((++p))

    echo "### Creating ROOT partition ${p} on ${DEVICE}..."
    timeout -k 15 10 bash -c -- "while ! parted ${DEVICE} -- mkpart primary zfs ${BOOT_END} ${ROOT_END}; do sleep 1; done"
    ROOT_IDS+=($(blkid ${DEVICE}-part${p} -o value -s PARTUUID))
    ((++p))

    if [[ "${ROOT_END}" != "${SWAP_END}" ]]
    then
        echo "### Creating SWAP partition ${p} on ${DEVICE}..."
        timeout -k 15 10 bash -c -- "while ! parted ${DEVICE} -- mkpart primary linux-swap ${ROOT_END} ${SWAP_END}; do sleep 1; done"
        SWAP_IDS+=($(blkid ${DEVICE}-part${p} -o value -s PARTUUID))
        ((++p))
    fi

    if [[ "${SWAP_END}" != "100%" ]]
    then
        echo "### Creating EXT partition ${p} on ${DEVICE}..."
        timeout -k 15 10 bash -c -- "while ! parted ${DEVICE} -- mkpart extended ${SWAP_END} 100%; do sleep 1; done"
        EXT_IDS+=($(blkid ${DEVICE}-part${p} -o value -s PARTUUID))
        ((++p))
    fi
done
cat >/tmp/partids << EOF
EFI_IDS=("${EFI_IDS[@]}")
BOOT_IDS=("${BOOT_IDS[@]}")
ROOT_IDS=("${ROOT_IDS[@]}")
SWAP_IDS=("${SWAP_IDS[@]}")
EXT_IDS=("${EXT_IDS[@]}")
EOF
sleep 1

# "$(cd "$(dirname "$0")" ; pwd)"/1.1-format-bulk.sh "$@"
"$(cd "$(dirname "$0")" ; pwd)"/1.1-format-swap.sh "$@"

echo "### Done partitioning!"
