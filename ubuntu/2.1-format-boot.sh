#!/bin/bash
set -e

source "$(cd "$(dirname "$0")" ; pwd)"/common.sh "$@"

echo "### Creating zpool boot..."
ZPOOL_OPTS=(
    -o ashift=12
    -d
    -o feature@async_destroy=enabled
    -o feature@bookmarks=enabled
    -o feature@embedded_data=enabled
    -o feature@empty_bpobj=enabled
    -o feature@enabled_txg=enabled
    -o feature@extensible_dataset=enabled
    -o feature@filesystem_limits=enabled
    -o feature@hole_birth=enabled
    -o feature@large_blocks=enabled
    -o feature@lz4_compress=enabled
    -o feature@spacemap_histogram=enabled
    -o feature@zpool_checkpoint=enabled
    -O acltype=posixacl
    -O compression=lz4
    -O devices=off
    -O normalization=formD
    -O relatime=on
    -O xattr=sa
    -O com.sun:auto-snapshot=false
    -R /target
)
BOOT_DEVS=()
for id in "${BOOT_IDS[@]}"
do
    BOOT_DEVS+=(/dev/disk/by-partuuid/${id})
done
MIRROR=mirror
if ((${#SYSTEM_DEVICES[@]} == 1))
then
    MIRROR=
fi
rm -rf /target
zpool create -f "${ZPOOL_OPTS[@]}" -m none boot ${MIRROR} "${BOOT_DEVS[@]}"
zfs unmount -a
zfs set mountpoint=/boot boot || true
zpool export boot
