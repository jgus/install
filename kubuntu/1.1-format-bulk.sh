#!/bin/bash -e

source "$(cd "$(dirname "$0")" ; pwd)"/common.sh "$@"

echo "### Cleaning up prior partitions..."
zpool destroy bulk || true

echo "### Creating zpool bulk... (${BULK_DEVICE})"
ZPOOL_OPTS=(
    -o ashift=12
    -O acltype=posixacl
    -O aclinherit=passthrough
    -O compression=lz4
    -O atime=off
    -O xattr=sa
    -O com.sun:auto-snapshot=false
    -R /target
    -f
)
[[ "${VKEY_FILE}" == "" ]] || ZPOOL_OPTS+=(
    -O encryption=on
    -O keyformat=raw
    -O keylocation=file://${VKEY_FILE}
)

zpool create -f "${ZPOOL_OPTS[@]}" -m /bulk bulk "${BULK_DEVICE}"
zfs unmount -a
zpool export bulk

echo "### Done partitioning!"
