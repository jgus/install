#!/bin/bash
set -e

HOSTNAME=$1
source "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/config.env

for i in "${!SYSTEM_DEVICES[@]}"
do
    DEVICE="${SYSTEM_DEVICES[$i]}"
    EFI_DEVS+=("${DEVICE}-part1")
done

echo "### Formatting EFI partitions... (${EFI_DEVS[@]})"
for i in "${!EFI_DEVS[@]}"
do
    mkfs.fat -F 32 -n "EFI${i}" "${EFI_DEVS[$i]}"
done
