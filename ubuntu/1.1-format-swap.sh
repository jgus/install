#!/bin/bash
set -e

HOSTNAME=$1
source "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/config.env
source /tmp/partids

KEY_FILE=${KEY_FILE:-/sys/firmware/efi/vars/keyfile-77fa9abd-0359-4d32-bd60-28f4e78f784b/data}

echo "### Setting up swap..."
# for i in /dev/mapper/*SWAP*
# do
#     swapoff "${i}" || true
# done

for i in "${!SWAP_IDS[@]}"
do
    cryptsetup --cipher=aes-xts-plain64 --key-size=256 --key-file="${KEY_FILE}" --allow-discards open --type plain "/dev/disk/by-partuuid/${SWAP_IDS[$i]}" ${HOSTNAME}-swap-${i}
    mkswap -L ${HOSTNAME}-swap-${i} /dev/mapper/${HOSTNAME}-swap-${i}
    swapon -p 100 /dev/mapper/${HOSTNAME}-swap-${i}
done
