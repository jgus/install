#!/bin/bash
set -e

HOSTNAME=$1
source "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/config.env
source /tmp/partids

KEY_FILE=${KEY_FILE:-/sys/firmware/efi/vars/keyfile-77fa9abd-0359-4d32-bd60-28f4e78f784b/data}

echo "### Creating zpool root..."
ZPOOL_OPTS=(
    -o ashift=12
    -O acltype=posixacl
    -O aclinherit=passthrough
    -O compression=lz4
    -O atime=off
    -O xattr=sa
    -O com.sun:auto-snapshot=true
    -O mountpoint=/
    -R /target
)
[[ "${KEY_FILE}" == "/zfs-keyfile" ]] || ZPOOL_OPTS+=(
    -O encryption=on
    -O keyformat=raw
    -O keylocation=file://${KEY_FILE}
)
ROOT_DEVS=()
for id in "${ROOT_IDS[@]}"
do
    ROOT_DEVS+=(/dev/disk/by-partuuid/${id})
done
zpool create -f "${ZPOOL_OPTS[@]}" root ${SYSTEM_Z_TYPE} "${ROOT_DEVS[@]}"
zfs create -o canmount=off                          -o com.sun:auto-snapshot=false  root/var
zfs create                                                                          root/var/cache
zfs create                                                                          root/var/log
zfs create                                                                          root/var/spool
zfs create                                                                          root/var/tmp
zfs create                                                                          root/home
zfs create -o mountpoint=/var/lib/docker            -o com.sun:auto-snapshot=false  root/docker
zfs create -o mountpoint=/var/volumes                                               root/volumes
zfs create                                          -o com.sun:auto-snapshot=false  root/volumes/scratch
zfs create -o mountpoint=/var/lib/libvirt/images                                    root/images
zfs create                                          -o com.sun:auto-snapshot=false  root/images/scratch
zfs set mountpoint=/ root || true

zfs unmount -a
zpool export root
