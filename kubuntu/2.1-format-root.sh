#!/bin/bash -e

source "$(cd "$(dirname "$0")" ; pwd)"/common.sh "$@"

echo "### Creating zpool root..."
ZPOOL_OPTS=(
    -o ashift=12
    -O acltype=posixacl
    -O aclinherit=passthrough
    -O canmount=off
    -O compression=lz4
    -O dnodesize=auto
    -O normalization=formD
    -O relatime=on
    -O xattr=sa
    -O mountpoint=/
    -O com.sun:auto-snapshot=false
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
zpool create -f "${ZPOOL_OPTS[@]}" -m none rpool ${SYSTEM_Z_TYPE} "${ROOT_DEVS[@]}"

zfs create -o canmount=off -o mountpoint=none rpool/ROOT
zfs create -o com.ubuntu.zsys:bootfs=yes -o com.ubuntu.zsys:last-used=$(date +%s) -o com.sun:auto-snapshot=true -o canmount=noauto -o mountpoint=/ rpool/ROOT/ubuntu_${ZFS_UUID}
zfs create -o com.ubuntu.zsys:bootfs=no -o canmount=off -o com.sun:auto-snapshot=false                          rpool/ROOT/ubuntu_${ZFS_UUID}/var
zfs create                                                                                                      rpool/ROOT/ubuntu_${ZFS_UUID}/var/cache
zfs create                                                                                                      rpool/ROOT/ubuntu_${ZFS_UUID}/var/log
zfs create                                                                                                      rpool/ROOT/ubuntu_${ZFS_UUID}/var/spool
zfs create                                                                                                      rpool/ROOT/ubuntu_${ZFS_UUID}/var/tmp

zfs create -o canmount=off                                                                  -o mountpoint=/                         rpool/USERDATA
zfs create -o canmount=on -o com.ubuntu.zsys:bootfs-datasets=rpool/ROOT/ubuntu_${ZFS_UUID}  -o mountpoint=/root                     rpool/USERDATA/root_${ZFS_UUID}
zfs create -o canmount=on                                                                   -o mountpoint=/home                     rpool/USERDATA/home
zfs create -o canmount=on -o com.sun:auto-snapshot=false                                    -o mountpoint=/var/lib/docker           rpool/USERDATA/docker
zfs create -o canmount=on                                                                   -o mountpoint=/var/volumes              rpool/USERDATA/volumes
zfs create                -o com.sun:auto-snapshot=false                                                                            rpool/USERDATA/volumes/scratch
zfs create -o canmount=on                                                                   -o mountpoint=/var/lib/libvirt/images   rpool/USERDATA/images
zfs create                -o com.sun:auto-snapshot=false                                                                            rpool/USERDATA/images/scratch

zfs unmount -a
zpool export rpool
