#!/bin/bash
set -e

HOSTNAME=$1
source "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/config.env

KEY_FILE=${KEY_FILE:-/sys/firmware/efi/vars/keyfile-77fa9abd-0359-4d32-bd60-28f4e78f784b/data}

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
    -O com.sun:auto-snapshot=true
    -R /target
    -f
)
[[ "${KEY_FILE}" == "_" ]] || ZPOOL_OPTS+=(
    -O encryption=on
    -O keyformat=raw
    -O keylocation=file://${KEY_FILE}
)

zpool create -f "${ZPOOL_OPTS[@]}" -m /bulk bulk "${BULK_DEVICE}"
zfs unmount -a
zpool export bulk

echo "### Done partitioning!"
