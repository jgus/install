#!/bin/bash
set -e

HOSTNAME=$1
source "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/config.env

echo "### Formatting EFI partitions..."
for i in "${!SYSTEM_DEVICES[@]}"
do
    mkfs.fat -F 32 -n "EFI${i}" /dev/disk/by-partlabel/${HOSTNAME}_EFI_${i}
done
