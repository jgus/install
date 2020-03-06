#!/bin/bash
set -e

HOSTNAME=$1
source "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/config.env

EFI_SIZE=${EFI_SIZE:-+256M}
BOOT_SIZE=${BOOT_SIZE:-+512M}
ROOT_SIZE=${ROOT_SIZE:-0}
KEY_FILE=${KEY_FILE:-/sys/firmware/efi/vars/keyfile-77fa9abd-0359-4d32-bd60-28f4e78f784b/data}

echo "### Cleaning up prior partitions..."
umount -Rl /target || true
zpool destroy root || true
for i in /dev/disk/by-label/SWAP*
do
    swapoff "${i}" || true
done

for i in "${!SYSTEM_DEVICES[@]}"
do
    DEVICE="${SYSTEM_DEVICES[$i]}"
    echo "### Wiping and re-partitioning ${DEVICE}..."
    sgdisk --zap-all "${DEVICE}"
    while [ -L "${DEVICE}-part2" ] ; do : ; done
    sgdisk -n1:1M:${EFI_SIZE} -t1:EF00 "${DEVICE}"
    sgdisk -n2:0:${BOOT_SIZE} -t2:8300 "${DEVICE}"
    sgdisk -n3:0:${ROOT_SIZE} -t3:BF00 "${DEVICE}"
    if [[ "${ROOT_SIZE}" != "0" ]]
    then
        sgdisk -n4:0:0 -t4:8200 "${DEVICE}"
    fi
    BOOT_DEVS+=("${DEVICE}-part2")
    ROOT_DEVS+=("${DEVICE}-part3")
    SWAP_DEVS+=("${DEVICE}-part4")
done
sleep 1

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
zfs create -o mountpoint=/var -o canmount=off       -o com.sun:auto-snapshot=false  root/var
zfs create                                                                          root/var/cache
zfs create                                                                          root/var/log
zfs create                                                                          root/var/spool
zfs create                                                                          root/var/tmp
zfs create -o mountpoint=/home                                                      root/home
zfs create -o mountpoint=/var/lib/docker                                            root/docker
zfs create -o mountpoint=/var/volumes               -o com.sun:auto-snapshot=true   root/volumes
zfs create                                          -o com.sun:auto-snapshot=false  root/volumes/scratch
zfs create -o mountpoint=/var/lib/libvirt/images    -o com.sun:auto-snapshot=true   root/images
zfs create                                          -o com.sun:auto-snapshot=false  root/images/scratch

zfs unmount -a
zpool export root

"$(cd "$(dirname "$0")" ; pwd)"/1.1-format-swap.sh "${HOSTNAME}"

echo "### Done partitioning!"
