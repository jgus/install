#!/bin/bash
set -e

HOSTNAME=$1
source "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/config.env

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
    -O mountpoint=/boot
    -O com.sun:auto-snapshot=false
    -R /target
)
zpool create -f "${ZPOOL_OPTS[@]}" -m none boot mirror /dev/disk/by-partlabel/${HOSTNAME}_BOOT_*

zfs unmount -a
zpool export boot
