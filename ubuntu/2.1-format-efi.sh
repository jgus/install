#!/bin/bash
set -e

HOSTNAME=$1
source "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/config.env
source /tmp/partids

echo "### Formatting EFI partitions..."
for i in "${!EFI_IDS[@]}"
do
    mkfs.fat -F 32 -n "EFI${i}" /dev/disk/by-partuuid/${EFI_IDS[$i]}
done
