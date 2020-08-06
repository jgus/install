#!/bin/bash -e

source "$(cd "$(dirname "$0")" ; pwd)"/common.sh "$@"

echo "### Creating zpool root..."
ZPOOL_OPTS=(
    -o ashift=12
    -O acltype=posixacl
    -O aclinherit=passthrough
    -O compression=lz4
    -O dnodesize=auto
    -O normalization=formD
    -O relatime=on
    -O xattr=sa
    -O mountpoint=/
    -O com.sun:auto-snapshot=true
    -R /target
)
case ${VKEY_TYPE} in
    efi)
        ZPOOL_OPTS+=(
            -O encryption=aes-256-gcm
            -O keyformat=raw
            -O keylocation=file://${VKEY_FILE}
        )
        ;;
    prompt)
        ZPOOL_OPTS+=(
            -O encryption=aes-256-gcm
            -O keyformat=passphrase
            -O keylocation=prompt
        )
        ;;
    root)
        ;;
esac

ROOT_DEVS=()
for id in "${ROOT_IDS[@]}"
do
    ROOT_DEVS+=(/dev/disk/by-partuuid/${id})
done
zpool create -f "${ZPOOL_OPTS[@]}" rpool ${SYSTEM_Z_TYPE} "${ROOT_DEVS[@]}"

zfs create -o com.sun:auto-snapshot=false   -o canmount=off                         rpool/var
zfs create                                                                          rpool/var/cache
zfs create                                                                          rpool/var/log
zfs create                                                                          rpool/var/spool
zfs create                                                                          rpool/var/tmp
zfs create -o com.sun:auto-snapshot=false   -o mountpoint=/var/lib/docker           rpool/docker
zfs create                                  -o mountpoint=/var/volumes              rpool/volumes
zfs create -o com.sun:auto-snapshot=false                                           rpool/volumes/scratch
zfs create                                  -o mountpoint=/var/lib/libvirt/images   rpool/images
zfs create -o com.sun:auto-snapshot=false                                           rpool/images/scratch
zfs create                                                                          rpool/home

zfs unmount -a
zpool export rpool
