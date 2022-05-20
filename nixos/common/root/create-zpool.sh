#!/usr/bin/env -S bash -e

SWAP_SIZE="8GiB"
Z_DEVS=()

for d in "$@"
do
    parted ${d} -- mklabel gpt
    parted ${d} -- mkpart primary linux-swap 0% ${SWAP_SIZE}
    parted ${d} -- mkpart primary ${SWAP_SIZE} 100%
    sleep 2
    Z_DEVS+=("${d}-part2")
    mkswap "${d}-part1"
    swapon "${d}-part1"
done

nixos-generate-config

ZPOOL_OPTS=(
    -o ashift=12
    -O acltype=posixacl
    -O aclinherit=passthrough
    -O compression=lz4
    -O dnodesize=auto
    -O normalization=formD
    -O relatime=on
    -O xattr=sa
    -O com.sun:auto-snapshot=true
    -O encryption=aes-256-gcm
    -O keyformat=raw
    -O keylocation=file:///root/vkey
)

zpool create -f "${ZPOOL_OPTS[@]}" d "${Z_DEVS[@]}"
