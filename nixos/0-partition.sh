#!/usr/bin/env -S bash -e

DEVICE=$1

#SWAP_SIZE_="${SWAP_SIZE:-8GiB}"
BOOT_N=1
ROOT_N=2
SWAP_N=3
BOOT_START="1MiB"
BOOT_END="${BOOT_SIZE}"
ROOT_START="${BOOT_SIZE}"
ROOT_END="-${SWAP_SIZE}"
SWAP_START="-${SWAP_SIZE}"
SWAP_END="100%"

i=0
while [ -b /dev/disk/by-partlabel/boot${i} ]
do
    ((i+=1))
done
BOOT_LABEL="boot${i}"

i=0
while [ -b /dev/disk/by-partlabel/root${i} ]
do
    ((i+=1))
done
ROOT_LABEL="root${i}"

i=0
while [ -b /dev/disk/by-partlabel/swap${i} ]
do
    ((i+=1))
done
SWAP_LABEL="swap${i}"

if [[ "${BOOT_SIZE}" == "100%" ]]
then
    echo "### Partitioning ${DEVICE} with boot partion only"
    parted ${DEVICE} -- mklabel gpt
    parted ${DEVICE} -- mkpart ESP fat32 1MiB 100%
    parted ${DEVICE} -- set 1 esp on
    parted ${DEVICE} -- name 1 ${BOOT_LABEL}

    while [ ! -b /dev/disk/by-partlabel/${BOOT_LABEL} ]
    do
        sleep 1
    done

    exit 0
fi

if [[ "${BOOT_SIZE}" == "100%" ]]
then
    echo "### Partitioning ${DEVICE} with swap partion only"
    parted ${DEVICE} -- mklabel gpt
    parted ${DEVICE} -- mkpart primary linux-swap 0% 100%
    parted ${DEVICE} -- name 1 ${SWAP_LABEL}

    while [ ! -b /dev/disk/by-partlabel/${SWAP_LABEL} ]
    do
        sleep 1
    done

    exit 0
fi

if [[ "${BOOT_SIZE}x" == "x" ]]
then
    echo "# Skipping boot partition"
    ROOT_N=1
    SWAP_N=2
    ROOT_START="0%"
fi

if [[ "${SWAP_SIZE}x" == "x" ]]
then
    echo "# Skipping swap partition"
    ROOT_END="100%"
fi


echo "### Partitioning ${DEVICE}"
parted ${DEVICE} -- mklabel gpt

if [[ "${BOOT_SIZE}x" != "x" ]]
then
    echo "# Creating boot partition"
    parted ${DEVICE} -- mkpart ESP fat32 "${BOOT_START}" "${BOOT_END}"
    parted ${DEVICE} -- set "${BOOT_N}" esp on
    parted ${DEVICE} -- name "${BOOT_N}" ${BOOT_LABEL}
fi

echo "# Creating root partition"
parted ${DEVICE} -- mkpart primary "${ROOT_START}" "${ROOT_END}"
parted ${DEVICE} -- name "${ROOT_N}" ${ROOT_LABEL}

if [[ "${SWAP_SIZE}x" != "x" ]]
then
    echo "# Creating swap partition"
    parted ${DEVICE} -- mkpart primary linux-swap "${SWAP_START}" "${SWAP_END}"
    parted ${DEVICE} -- name "${SWAP_N}" ${SWAP_LABEL}
fi

while [ ! -b /dev/disk/by-partlabel/${ROOT_LABEL} ]
do
    sleep 1
done
