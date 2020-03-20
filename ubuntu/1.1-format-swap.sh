#!/bin/bash
set -e

HOSTNAME=$1
source "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/config.env

KEY_FILE=${KEY_FILE:-/sys/firmware/efi/vars/keyfile-77fa9abd-0359-4d32-bd60-28f4e78f784b/data}

for i in "${!SYSTEM_DEVICES[@]}"
do
    DEVICE="${SYSTEM_DEVICES[$i]}"
    SWAP_DEVS+=("${DEVICE}-part4")
done

echo "### Setting up swap... (${SWAP_DEVS[@]})"
for i in /dev/disk/by-label/SWAP*
do
    swapoff "${i}" || true
done

for i in "${!SWAP_DEVS[@]}"
do
    if [[ -b "${SWAP_DEVS[$i]}" ]]
    then
        cryptsetup --cipher=aes-xts-plain64 --key-size=256 --key-file="${KEY_FILE}" --allow-discards open --type plain "${SWAP_DEVS[$i]}" swap${i}
        mkswap -L SWAP${i} /dev/mapper/swap${i}
        swapon -p 100 /dev/mapper/swap${i}
    fi
done
