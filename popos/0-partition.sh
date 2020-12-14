#!/bin/bash -e

HOSTNAME=$1
source "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/config.env

BOOT_SIZE=${BOOT_SIZE:-2}
WIN_SIZE=${WIN_SIZE:-0}
SWAP_SIZE=${SWAP_SIZE:-$(free --giga | grep \^Mem | awk '{print $2}')}

echo "### Cleaning up prior partitions..."
for d in $(ls /dev/mapper/swap*); do cryptsetup close ${i} || true; done
mount | grep -v zfs | tac | awk '/\/target/ {print $3}' | xargs -i{} umount -lf {}
zfs unmount -a || true
zpool export z || true
zpool destroy z || true
rm -rf /target || true

echo "### Partitioning..."
for i in "${!SYSTEM_DEVICES[@]}"
do
    DEVICE=${SYSTEM_DEVICES[$i]}
    echo "### Wiping and re-partitioning ${DEVICE}..."
    blkdiscard -f "${DEVICE}" || true
    wipefs -af "${DEVICE}"
    parted -s "${DEVICE}" -- mklabel gpt

    TOTAL_SIZE=$(($(blockdev --getsize64 ${DEVICE}) / (1024 * 1024 * 1024)))

    BOOT_END=${BOOT_SIZE}
    parted -s -a optimal "${DEVICE}" -- mkpart "BOOT${i}" fat32 '0%' "${BOOT_END}GiB"
    parted -s "${DEVICE}" -- set 1 esp on

    if ((WIN_SIZE))
    then
        WIN_END=$((BOOT_END+WIN_SIZE))
        parted -s -a optimal "${DEVICE}" -- mkpart "WIN${i}" NTFS "${BOOT_END}GiB" "${WIN_END}GiB"
    else
        WIN_END=${BOOT_END}
    fi

    if ((SWAP_SIZE))
    then
        SWAP_END=$((WIN_END+SWAP_SIZE))
        parted -s -a optimal "${DEVICE}" -- mkpart "SWAP${i}" NTFS "${WIN_END}GiB" "${SWAP_END}GiB"
    else
        SWAP_END=${WIN_END}
    fi

    parted -s -a optimal "${DEVICE}" -- mkpart "ZFS${i}" "${SWAP_END}GiB" '100%'
done

echo "### Ready to install Pop_OS"
echo "Install boot on BOOT0 and root on WIN0."
echo "After install, use disk util to re-set partition names (install will have cleared them.)"
echo "Then run ./1-zfs.sh ${HOSTNAME}"
