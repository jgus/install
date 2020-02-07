#!/bin/bash
set -e

HOSTNAME=$1
source "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/config.env

for i in "${!SYSTEM_DEVICES[@]}"
do
    DEVICE="${SYSTEM_DEVICES[$i]}"
    BOOT_DEVS+=("${DEVICE}-part1")
done

echo "### Formatting boot partitions... (${BOOT_DEVS[@]})"
for i in "${!BOOT_DEVS[@]}"
do
    mkfs.fat -F 32 -n "BOOT${i}" "${BOOT_DEVS[$i]}"
done
