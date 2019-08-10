#!/bin/sh
set -e

# Key
# usb-SanDisk_Cruzer_Fit_4C532000050323115155-0:0
DEVICE=/dev/disk/by-id/usb-SanDisk_Cruzer_Fit_4C532000050323115155-0:0

parted -s "${DEVICE}" -- mklabel msdos
parted -s "${DEVICE}" -- mkpart primary fat32 4MiB -1s
mkfs.fat -F 32 -n BOOTKEY "${DEVICE}-part1"
