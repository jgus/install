#!/usr/bin/env -S bash -e

VKEY_FILE="${VKEY_FILE:-/boot/vkey}"

if [ ! -f "${VKEY_FILE}" ]
then
    mkdir -p "$(dirname "${VKEY_FILE}")"
    dd bs=1 count=32 if=/dev/urandom of="${VKEY_FILE}"
fi

echo "### Formatting root as zfs"
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
    -O encryption=aes-256-gcm
    -O keyformat=raw
    -O keylocation=file://${VKEY_FILE}
    -R /mnt
)

zpool create -f "${ZPOOL_OPTS[@]}" rpool /dev/disk/by-partlabel/root

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
