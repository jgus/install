#!/usr/bin/env -S bash -e

KEY_GUID=77fa9abd-0359-4d32-bd60-28f4e78f784b
if [ ! -f /sys/firmware/efi/vars/keyfile32-${KEY_GUID}/data ] && [ ! -f /sys/firmware/efi/efivars/keyfile28-${KEY_GUID} ]
then
    TMPFILE=$(mktemp)
    dd bs=1 count=32 if=/dev/urandom of="${TMPFILE}"
    efivar -n 77fa9abd-0359-4d32-bd60-28f4e78f784b-keyfile32 -t 7 -w -f "${TMPFILE}"
    rm "${TMPFILE}"
    dd bs=1 count=28 if=/dev/urandom of="${TMPFILE}"
    efivar -n 77fa9abd-0359-4d32-bd60-28f4e78f784b-keyfile28 -t 7 -w -f "${TMPFILE}"
    rm "${TMPFILE}"
fi
VKEY_FILE=/sys/firmware/efi/vars/keyfile32-${KEY_GUID}/data
[ -f "${VKEY_FILE}"] || VKEY_FILE=/sys/firmware/efi/efivars/keyfile28-${KEY_GUID}
[ -f "${VKEY_FILE}"] || (echo "!!! Could not find KVEY_FILE"; exit 1)

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
#zfs create -o com.sun:auto-snapshot=false   -o mountpoint=/var/lib/docker           rpool/docker
#zfs create                                  -o mountpoint=/var/volumes              rpool/volumes
#zfs create -o com.sun:auto-snapshot=false                                           rpool/volumes/scratch
#zfs create                                  -o mountpoint=/var/lib/libvirt/images   rpool/images
#zfs create -o com.sun:auto-snapshot=false                                           rpool/images/scratch
zfs create                                                                          rpool/home
