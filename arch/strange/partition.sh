#!/bin/bash
set -e

# System
SYSTEM_DEVICES=(
    ata-SanDisk_SDSSDX240GG25_130811402135
    ata-SanDisk_SDSSDX240GG25_131102400461
    ata-SanDisk_SDSSDX240GG25_131102401287
    ata-SanDisk_SDSSDX240GG25_131102402736
    )

echo "Cleaning up prior ZFS pools..."
zpool destroy boot || true
zpool destroy z || true

echo "Cleaning up prior LVM config..."
vgremove -f vg || true
for i in "${!SYSTEM_DEVICES[@]}"
do
    pvremove -f "/dev/disk/by-id/${SYSTEM_DEVICES[$i]}"* || true
done

SYSTEM_PVS=()
for i in "${!SYSTEM_DEVICES[@]}"
do
    DEVICE="/dev/disk/by-id/${SYSTEM_DEVICES[$i]}"
    echo "Wiping and re-partitioning ${DEVICE}..."
    parted -s "${DEVICE}" -- mklabel gpt
    while [ -L "${DEVICE}-part2" ] ; do : ; done
    parted -s "${DEVICE}" -- mkpart primary 4MiB 512MiB
    parted -s "${DEVICE}" -- set 1 esp on
    parted -s "${DEVICE}" -- mkpart primary 512MiB 100%
    while [ ! -L "${DEVICE}-part2" ] ; do : ; done
    SYSTEM_PVS+=("${DEVICE}-part2")
done

echo "Setting up LVM..."
vgcreate vg "${SYSTEM_PVS[@]}"

SYSTEM_BOOT_DEVS=()
SYSTEM_Z_DEVS=()
for i in "${!SYSTEM_DEVICES[@]}"
do
    echo "Formatting UEFI-${i}..."
    mkfs.fat -F32 "/dev/disk/by-id/${SYSTEM_DEVICES[$i]}-part1" -n UEFI-${i}
    echo "Creating LV boot${i}..."
    yes | lvcreate -Wy -L 512M -n boot${i} vg "${SYSTEM_PVS[$i]}"
    echo "Creating LV z${i}..."
    yes | lvcreate -Wy -L 210G -n z${i} vg "${SYSTEM_PVS[$i]}"
    SYSTEM_BOOT_DEVS+=("/dev/vg/boot${i}")
    SYSTEM_Z_DEVS+=("/dev/vg/z${i}")
done

echo "Creating LV swap..."
yes | lvcreate -Wy -l 100%FREE -n swap -i "${#SYSTEM_DEVICES[@]}" vg
mkswap /dev/vg/swap

echo "Creating zpool boot..."
zpool create \
    -d \
    -o feature@allocation_classes=enabled \
    -o feature@async_destroy=enabled      \
    -o feature@bookmarks=enabled          \
    -o feature@embedded_data=enabled      \
    -o feature@empty_bpobj=enabled        \
    -o feature@enabled_txg=enabled        \
    -o feature@extensible_dataset=enabled \
    -o feature@filesystem_limits=enabled  \
    -o feature@hole_birth=enabled         \
    -o feature@large_blocks=enabled       \
    -o feature@lz4_compress=enabled       \
    -o feature@project_quota=enabled      \
    -o feature@resilver_defer=enabled     \
    -o feature@spacemap_histogram=enabled \
    -o feature@spacemap_v2=enabled        \
    -o feature@userobj_accounting=enabled \
    -o feature@zpool_checkpoint=enabled   \
    -o ashift=12 \
    -O atime=off \
    -O compression=lz4 \
    -m none \
    boot raidz "${SYSTEM_BOOT_DEVS[@]}"

echo "Creating zpool main..."
mkdir -p /bootkey
mount -o ro /dev/disk/by-label/BOOTKEY /bootkey
zpool create \
    -o ashift=12 \
    -O atime=off \
    -O compression=lz4 \
    -O encryption=on \
    -O keyformat=raw \
    -O keylocation=file:///bootkey/key \
    -m none \
    z raidz "${SYSTEM_Z_DEVS[@]}"
umount /bootkey

echo "Unmounting zpools..."
zfs unmount -a

echo "Unmounting zfs datasets..."
zfs create z/root
zfs create -o canmount=off z/root/var
zfs create z/root/var/cache
zfs create z/root/var/log
zfs create z/root/var/spool
zfs create z/root/var/tmp
zfs create z/home
zfs create z/docker

zpool set bootfs=boot boot
zpool set bootfs=z/root z

echo "Exporting zfs datasets..."
zpool export boot
zpool export z

# Bulk
# ata-WDC_WD60EFRX-68MYMN1_WD-WX11DA4DJ3CN

echo "Done partitioning!"
