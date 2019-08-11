#!/bin/sh
set -e

# System
# ata-SanDisk_SDSSDX240GG25_130811402135
# ata-SanDisk_SDSSDX240GG25_131102400461
# ata-SanDisk_SDSSDX240GG25_131102401287
# ata-SanDisk_SDSSDX240GG25_131102402736
for s in 130811402135 131102400461 131102401287 131102402736
do
    DEVICE=/dev/disk/by-id/ata-SanDisk_SDSSDX240GG25_${s}
    parted -s "${DEVICE}" -- mklabel gpt
    parted -s "${DEVICE}" -- mkpart primary 4MiB 512MiB
    parted -s "${DEVICE}" -- set 1 esp on
    parted -s "${DEVICE}" -- mkpart primary fat32 512MiB -1s
done

mkfs.fat -F32 /dev/disk/by-id/ata-SanDisk_SDSSDX240GG25_130811402135-part1
mkfs.fat -F32 /dev/disk/by-id/ata-SanDisk_SDSSDX240GG25_131102400461-part1
mkfs.fat -F32 /dev/disk/by-id/ata-SanDisk_SDSSDX240GG25_131102401287-part1
mkfs.fat -F32 /dev/disk/by-id/ata-SanDisk_SDSSDX240GG25_131102402736-part1

vgcreate system /dev/disk/by-id/ata-SanDisk_SDSSDX240GG25_130811402135-part2 /dev/disk/by-id/ata-SanDisk_SDSSDX240GG25_131102400461-part2 /dev/disk/by-id/ata-SanDisk_SDSSDX240GG25_131102401287-part2 /dev/disk/by-id/ata-SanDisk_SDSSDX240GG25_131102402736-part2

lvcreate -Wy -L 512M -n boot -i 4 system
lvcreate -Wy -L 210G -n z0 system /dev/disk/by-id/ata-SanDisk_SDSSDX240GG25_130811402135-part2
lvcreate -Wy -L 210G -n z1 system /dev/disk/by-id/ata-SanDisk_SDSSDX240GG25_131102400461-part2
lvcreate -Wy -L 210G -n z2 system /dev/disk/by-id/ata-SanDisk_SDSSDX240GG25_131102401287-part2
lvcreate -Wy -L 210G -n z3 system /dev/disk/by-id/ata-SanDisk_SDSSDX240GG25_131102402736-part2
lvcreate -Wy -l 100%FREE -n swap -i 4 system

mkfs.ext4 /dev/system/boot
mkfs.ext4 /dev/system/z0
mkswap /dev/system/swap
swapon /dev/system/swap


# Bulk
# ata-WDC_WD60EFRX-68MYMN1_WD-WX11DA4DJ3CN

