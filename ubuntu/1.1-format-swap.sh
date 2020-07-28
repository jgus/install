#!/bin/bash
set -e

HOSTNAME=$1
source "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/config.env

KEY_FILE=${KEY_FILE:-/sys/firmware/efi/vars/keyfile-77fa9abd-0359-4d32-bd60-28f4e78f784b/data}

echo "### Setting up swap..."
for i in /dev/mapper/*SWAP*
do
    swapoff "${i}" || true
done

for p in $(cd /dev/disk/by-partlabel; ls ${HOSTNAME}_SWAP_*)
do
    cryptsetup --cipher=aes-xts-plain64 --key-size=256 --key-file="${KEY_FILE}" --allow-discards open --type plain "/dev/disk/by-partlabel/${p}" ${p}
    mkswap -L ${p} /dev/mapper/${p}
    swapon -p 100 /dev/mapper/${p}
done
