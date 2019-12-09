#!/bin/bash
set -e

HOSTNAME=$1
source "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/config.env

BOOT_SIZE=${BOOT_SIZE:-512M}
KEY_FILE=/sys/firmware/efi/efivars/keyfile-77fa9abd-0359-4d32-bd60-28f4e78f784b

echo "### Cleaning up prior partitions..."
umount -Rl /target || true
zpool destroy z || true
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
    sgdisk -n1:1M:+${BOOT_SIZE} -t1:EF00 "${DEVICE}"
    sgdisk -n2:0:+${Z_SIZE} -t2:BF00 "${DEVICE}"
    sgdisk -n3:0:0 -t3:8200 "${DEVICE}"
    Z_DEVS+=("${DEVICE}-part2")
    SWAP_DEVS+=("${DEVICE}-part3")
done
sleep 1

echo "### Creating zpool z... (${Z_DEVS[@]})"
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
zpool create -f "${ZPOOL_OPTS[@]}" -m none z ${SYSTEM_Z_TYPE} "${Z_DEVS[@]}"
zfs create -o mountpoint=/var -o canmount=off       -o com.sun:auto-snapshot=false  z/var
zfs create                                                                          z/var/cache
zfs create                                                                          z/var/log
zfs create                                                                          z/var/spool
zfs create                                                                          z/var/tmp
zfs create -o mountpoint=/home                                                      z/home
zfs create -o mountpoint=/var/lib/docker                                            z/docker
zfs create -o mountpoint=/var/volumes               -o com.sun:auto-snapshot=true   z/volumes
zfs create                                          -o com.sun:auto-snapshot=false  z/volumes/scratch
zfs create -o mountpoint=/var/lib/libvirt/images    -o com.sun:auto-snapshot=true   z/images
zfs create                                          -o com.sun:auto-snapshot=false  z/images/scratch
zfs unmount -a
zpool export z

"$(cd "$(dirname "$0")" ; pwd)"/1.1-format-boot.sh "${HOSTNAME}"
"$(cd "$(dirname "$0")" ; pwd)"/1.1-format-swap.sh "${HOSTNAME}"
"$(cd "$(dirname "$0")" ; pwd)"/1.1-format-bulk.sh "${HOSTNAME}"

echo "### Done partitioning!"
