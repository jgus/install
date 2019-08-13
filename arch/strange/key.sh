#!/bin/sh
set -e

# Key
# usb-SanDisk_Cruzer_Fit_4C532000050323115155-0:0
DEVICE=/dev/disk/by-id/usb-SanDisk_Cruzer_Fit_4C532000050323115155-0:0

parted -s "${DEVICE}" -- mklabel msdos
parted -s "${DEVICE}" -- mkpart primary fat32 4MiB -1s
mkfs.fat -F 32 -n BOOTKEY "${DEVICE}-part1"

mkdir -p /bootkey
mount /dev/disk/by-label/BOOTKEY /bootkey
mkdir -p /bootkey/keys
dd bs=512 count=8 if=/dev/random of=/bootkey/keys/root iflag=fullblock
umount /bootkey
