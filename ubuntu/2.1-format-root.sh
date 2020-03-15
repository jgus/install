#!/bin/bash
set -e


echo "### Creating zpool root... (${ROOT_DEVS[@]})"
ZPOOL_OPTS=(
    -o ashift=12
    -O acltype=posixacl
    -O aclinherit=passthrough
    -O compression=lz4
    -O atime=off
    -O xattr=sa
    -O com.sun:auto-snapshot=true
    -R /target
    -f
)
[[ "${KEY_FILE}" == "" ]] || ZPOOL_OPTS+=(
    -O encryption=on
    -O keyformat=raw
    -O keylocation=file://${KEY_FILE}
)
zpool create -f "${ZPOOL_OPTS[@]}" -m none root ${SYSTEM_Z_TYPE} "${ROOT_DEVS[@]}"
zfs create -o mountpoint=none                                                       root/root
zfs create -o mountpoint=/var -o canmount=off       -o com.sun:auto-snapshot=false  root/var
zfs create                                                                          root/var/cache
zfs create                                                                          root/var/log
zfs create                                                                          root/var/spool
zfs create                                                                          root/var/tmp
zfs create -o mountpoint=/home                                                      root/home
zfs create -o mountpoint=/var/lib/docker            -o com.sun:auto-snapshot=false  root/docker
zfs create -o mountpoint=/var/volumes               -o com.sun:auto-snapshot=true   root/volumes
zfs create                                          -o com.sun:auto-snapshot=false  root/volumes/scratch
zfs create -o mountpoint=/var/lib/libvirt/images    -o com.sun:auto-snapshot=true   root/images
zfs create                                          -o com.sun:auto-snapshot=false  root/images/scratch
zfs set mountpoint=/ root/root || true

zfs unmount -a
zpool export root
