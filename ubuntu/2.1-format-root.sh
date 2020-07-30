#!/bin/bash
set -e

source "$(cd "$(dirname "$0")" ; pwd)"/common.sh "$@"

echo "### Creating zpool root..."
ZPOOL_OPTS=(
    -o ashift=12
    -O acltype=posixacl
    -O aclinherit=passthrough
    -O compression=lz4
    -O atime=off
    -O xattr=sa
    -O com.sun:auto-snapshot=true
    -R /target
)
case ${ZFS_KEY}
    efi)
        ZPOOL_OPTS+=(
            -O encryption=on
            -O keyformat=raw
            -O keylocation=file://${KEY_FILE}
        )
        ;;
    prompt)
        ZPOOL_OPTS+=(
            -O encryption=on
            -O keyformat=passphrase
            -O keylocation=prompt
        )
        ;;
    root|none)
        ;;
esac

ROOT_DEVS=()
for id in "${ROOT_IDS[@]}"
do
    ROOT_DEVS+=(/dev/disk/by-partuuid/${id})
done
zpool create -f "${ZPOOL_OPTS[@]}" -m none root ${SYSTEM_Z_TYPE} "${ROOT_DEVS[@]}"
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
zfs unmount -a
zfs set mountpoint=/ root || true
zpool export root
