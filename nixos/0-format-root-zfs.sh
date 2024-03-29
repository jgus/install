#!/usr/bin/env -S bash -e

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
    -R /mnt
)

DEVS=()
for d in /dev/disk/by-partlabel/root*
do
    DEVS+=(/dev/disk/by-partuuid/$(blkid -o value -s PARTUUID "${d}"))
done

zpool create -f "${ZPOOL_OPTS[@]}" rpool mirror "${DEVS[@]}"

zfs create                                   -o mountpoint=/etc/nixos               rpool/nixos
zfs create                                                                          rpool/home
zfs create                                   -o mountpoint=/root                    rpool/home/root
