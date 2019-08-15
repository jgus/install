#!/bin/bash
set -e

umount /keyfile || true
mkdir -p /keyfile
mount -o ro "/dev/disk/by-label/KEYFILE" /keyfile

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

BOOT_DEVS=()
LOCKED_Z_DEVS=()
SWAP_DEVS=()
for i in "${!SYSTEM_DEVICES[@]}"
do
    DEVICE="/dev/disk/by-id/${SYSTEM_DEVICES[$i]}"
    echo "Wiping and re-partitioning ${DEVICE}..."
    wipefs --all "${DEVICE}"
    parted -s "${DEVICE}" -- mklabel gpt
    while [ -L "${DEVICE}-part2" ] ; do : ; done
    parted -s "${DEVICE}" -- mkpart primary 4MiB 512MiB
    parted -s "${DEVICE}" -- set 1 esp on
    parted -s "${DEVICE}" -- mkpart primary 512MiB 1024MiB
    parted -s "${DEVICE}" -- mkpart primary 1024MiB 211GiB
    parted -s "${DEVICE}" -- mkpart primary 211GiB 100%
    BOOT_DEVS+=("${DEVICE}-part2")
    LOCKED_Z_DEVS+=("${DEVICE}-part3")
    SWAP_DEVS+=("${DEVICE}-part4")
done
sleep 1

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
    -f \
    boot raidz "${BOOT_DEVS[@]}"
zfs unmount -a
zpool set bootfs=boot boot
zpool export boot

echo "Setting up z LUKS..."
Z_DEVS=()
for i in "${!LOCKED_Z_DEVS[@]}"
do
    cryptsetup -vq --type luks2 --key-file=/keyfile/system --label="lockedz${i}" luksFormat "${LOCKED_Z_DEVS[$i]}"
    cryptsetup --key-file=/keyfile/system open "/dev/disk/by-label/lockedz${i}" "z${i}"
    Z_DEVS+=("/dev/mapper/z${i}")
done

echo "Creating zpool main..."
zpool create \
    -o ashift=12 \
    -O atime=off \
    -O compression=lz4 \
    -m none \
    -f \
    z raidz "${Z_DEVS[@]}"
zfs create z/root
zfs create -o canmount=off z/root/var
zfs create z/root/var/cache
zfs create z/root/var/log
zfs create z/root/var/spool
zfs create z/root/var/tmp
zfs create z/home
zfs create z/docker
zfs unmount -a
zpool set bootfs=z/root z
zpool export z

for i in "${!LOCKED_Z_DEVS[@]}"
do
    cryptsetup close "z${i}"
done

echo "Setting up swap..."
for i in "${!SWAP_DEVS[@]}"
do
    mkswap -L"SWAP${i}" "${SWAP_DEVS[$i]}"
done

# Bulk
# ata-WDC_WD60EFRX-68MYMN1_WD-WX11DA4DJ3CN

echo "Done partitioning!"
