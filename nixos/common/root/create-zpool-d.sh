#!/usr/bin/env -S bash -e

SWAP_SIZE_="${SWAP_SIZE:-0%}"

Z_DEVS=()

[ -f /root/vkey ] || dd bs=1 count=32 if=/dev/urandom of=/root/vkey

for d in "$@"
do
    parted ${d} -- mklabel gpt
    Z_DEV_N=1
    if [[ "${SWAP_SIZE}" != "0%" ]]
    then
        parted ${d} -- mkpart primary linux-swap 0% ${SWAP_SIZE}
        Z_DEV_N=2
    fi
    parted ${d} -- mkpart primary ${SWAP_SIZE} 100%
    sleep 2
    Z_DEVS+=("${d}-part${Z_DEV_N}")
    if [[ "${SWAP_SIZE}" != "0%" ]]
    then
        mkswap "${d}-part1"
        swapon "${d}-part1"
    fi
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
    -O autobackup:offsite-$(hostname)=true
    -O autobackup:snap-$(hostname)=true
    -O encryption=aes-256-gcm
    -O keyformat=raw
    -O keylocation=file:///root/vkey
)

zpool create -f "${ZPOOL_OPTS[@]}" d "${Z_DEVS[@]}"
