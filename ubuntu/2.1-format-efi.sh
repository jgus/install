#!/bin/bash
set -e

source "$(cd "$(dirname "$0")" ; pwd)"/common.sh "$@"

echo "### Formatting EFI partitions..."
for i in "${!EFI_IDS[@]}"
do
    mkfs.fat -F 32 -n "EFI${i}" /dev/disk/by-partuuid/${EFI_IDS[$i]}
done
