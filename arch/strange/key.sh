#!/bin/sh
set -e

pacman -S --needed --noconfirm rng-tools
systemctl start rngd.service

# Key
# usb-SanDisk_Cruzer_Fit_4C532000050323115155-0:0
DEVICE=/dev/disk/by-id/usb-SanDisk_Cruzer_Fit_4C532000050323115155-0:0

parted -s "${DEVICE}" -- mklabel gpt
parted -s "${DEVICE}" -- mkpart primary ext2 4MiB 8MiB
parted -s "${DEVICE}" -- mkpart primary fat32 8MiB 100%
mkfs.ext2 -L BOOTKEY "${DEVICE}-part1"
mkfs.fat -F 32 -n INTERNAL "${DEVICE}-part2"

mkdir -p /bootkey
mount /dev/disk/by-label/BOOTKEY /bootkey
dd bs=1 count=32 if=/dev/random of=/bootkey/key status=progress
chmod 400 /bootkey/key
umount /bootkey
