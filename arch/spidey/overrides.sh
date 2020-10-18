do_partition() {
    WINDOWS_SIZE=192
    for i in "${!SYSTEM_DEVICES[@]}"
    do
        DEVICE=${SYSTEM_DEVICES[$i]}
        echo "### Wiping and re-partitioning ${DEVICE}..."
        blkdiscard -f "${DEVICE}" || true
        wipefs -af "${DEVICE}"
        parted -s "${DEVICE}" -- mklabel gpt
        while [ -L "${DEVICE}-part2" ] ; do : ; done
        echo "### Creating boot partition on ${DEVICE}..."
        parted -s -a optimal "${DEVICE}" -- mkpart primary fat32 '0%' "${BOOT_SIZE}GiB"
        parted -s "${DEVICE}" -- set 1 esp on
        echo "### Creating ZFS partition on ${DEVICE}..."
        parted -s -a optimal "${DEVICE}" -- mkpart primary "${BOOT_SIZE}GiB" "-$((SWAP_SIZE+WINDOWS_SIZE))GiB"
        echo "### Creating swap partition on ${DEVICE}..."
        parted -s -a optimal "${DEVICE}" -- mkpart primary ntfs "-$((SWAP_SIZE+WINDOWS_SIZE))GiB" "-${WINDOWS_SIZE}GiB"
        echo "### Creating Windows partition on ${DEVICE}..."
        parted -s -a optimal "${DEVICE}" -- mkpart primary ntfs "-${WINDOWS_SIZE}GiB" '100%'
        sleep 1
        BOOT_DEVS+=("${DEVICE}-part1")
        BOOT_IDS+=($(blkid ${DEVICE}-part1 -o value -s PARTUUID))
        Z_DEVS+=("${DEVICE}-part2")
        Z_IDS+=($(blkid ${DEVICE}-part2 -o value -s PARTUUID))
        SWAP_DEVS+=("${DEVICE}-part3")
        SWAP_IDS+=($(blkid ${DEVICE}-part3 -o value -s PARTUUID))
        mkfs.ntfs -f -L NTFS${i} "${DEVICE}-part4"
    done
    BOOT_DEVS=("${SYSTEM_DEVICES[0]}-part1")
    BOOT_IDS=($(blkid ${SYSTEM_DEVICES[0]}-part1 -o value -s PARTUUID))
}
