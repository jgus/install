#!/bin/bash
set -e

HOSTNAME=$(hostname)

DEVICE=$1

MBR_GAP=2MiB
EFI_END=4MiB
BOOT_END=2048MiB
SWAP_END=4096MiB
ROOT_END=36GiB

VKEY_FILE="/mnt/internal/vkey"

echo "### Wiping and re-partitioning ${DEVICE}..."
blkdiscard "${DEVICE}" || true
parted ${DEVICE} -- mklabel gpt
sleep 2

p=1

echo "### Creating GRUB BOOT partition ${p} on ${DEVICE}..."
timeout -k 15 10 bash -c -- "while ! parted ${DEVICE} -- mkpart primary fat32 ${MBR_GAP} ${EFI_END}; do sleep 1; done"
parted ${DEVICE} -- set ${p} bios_grub on
sleep 1
((++p))

echo "### Creating BOOT partition ${p} on ${DEVICE}..."
timeout -k 15 10 bash -c -- "while ! parted ${DEVICE} -- mkpart primary zfs ${EFI_END} ${BOOT_END}; do sleep 1; done"
sleep 1
BOOT_ID=$(blkid ${DEVICE}-part${p} -o value -s PARTUUID)
((++p))

echo "### Creating SWAP partition ${p} on ${DEVICE}..."
timeout -k 15 10 bash -c -- "while ! parted ${DEVICE} -- mkpart primary linux-swap ${BOOT_END} ${SWAP_END}; do sleep 1; done"
sleep 1
SWAP_ID=$(blkid ${DEVICE}-part${p} -o value -s PARTUUID)
((++p))

echo "### Creating ROOT partition ${p} on ${DEVICE}..."
timeout -k 15 10 bash -c -- "while ! parted ${DEVICE} -- mkpart primary zfs ${SWAP_END} ${ROOT_END}; do sleep 1; done"
sleep 1
ROOT_ID=$(blkid ${DEVICE}-part${p} -o value -s PARTUUID)
((++p))

echo "### Creating EXT partition ${p} on ${DEVICE}..."
timeout -k 15 10 bash -c -- "while ! parted ${DEVICE} -- mkpart extended ${ROOT_END} 100%; do sleep 1; done"
sleep 1
EXT_ID=$(blkid ${DEVICE}-part${p} -o value -s PARTUUID)
((++p))

echo "### Setting up swap..."
i=$(ls -1 /dev/mapper/${HOSTNAME}-swap-* | wc -l)
cryptsetup --cipher=aes-xts-plain64 --key-size=256 --key-file=${VKEY_FILE} --allow-discards open --type plain "/dev/disk/by-partuuid/${SWAP_ID}" ${HOSTNAME}-swap-${i}
mkswap -L swap-${i}-${HOSTNAME} /dev/mapper/${HOSTNAME}-swap-${i}
swapon -p 100 /dev/mapper/${HOSTNAME}-swap-${i}

echo "### Growing boot pool..."
CURRENT=$(zpool list bpool -vH | head -2 | tail -1 | awk '{print $1}')
zpool attach bpool ${CURRENT} ${BOOT_ID}

echo "### Growing root pool..."
CURRENT=$(zpool list rpool -vH | head -2 | tail -1 | awk '{print $1}')
zpool attach rpool ${CURRENT} ${ROOT_ID}

echo "### Installing GRUB..."
grub-install --target=i386-pc "${DEVICE}"

echo "### Done adding disk ${DEVICE}!"
