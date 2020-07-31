#!/bin/bash -e

source "$(cd "$(dirname "$0")" ; pwd)"/common.sh "$@"

echo "### Setting up swap..."
for i in $(swapon --show=NAME --noheadings)
do
    swapoff "${i}" || true
done
for i in $(cd /dev/mapper; ls ${HOSTNAME}-swap-*)
do
    cryptsetup close "${i}" || true
done

for i in "${!SWAP_IDS[@]}"
do
    cryptsetup --cipher=aes-xts-plain64 --key-size=256 --key-file=/dev/urandom --allow-discards open --type plain "/dev/disk/by-partuuid/${SWAP_IDS[$i]}" ${HOSTNAME}-swap-${i}
    mkswap -L swap-${i}-${HOSTNAME} /dev/mapper/${HOSTNAME}-swap-${i}
    swapon -p 100 /dev/mapper/${HOSTNAME}-swap-${i}
done
