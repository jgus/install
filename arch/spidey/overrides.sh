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

        TOTAL_SIZE=$(($(blockdev --getsize64 ${DEVICE}) / (1024 * 1024 * 1024)))
        END1=${BOOT_SIZE}
        END2=$((TOTAL_SIZE-WINDOWS_SIZE-SWAP_SIZE))
        END3=$((TOTAL_SIZE-WINDOWS_SIZE))

        echo "### Creating boot partition on ${DEVICE}..."
        parted -s -a optimal "${DEVICE}" -- mkpart primary fat32 '0%' "${END1}GiB"
        parted -s "${DEVICE}" -- set 1 esp on
        echo "### Creating ZFS partition on ${DEVICE}..."
        parted -s -a optimal "${DEVICE}" -- mkpart primary "${END1}GiB" "${END2}GiB"
        echo "### Creating swap partition on ${DEVICE}..."
        parted -s -a optimal "${DEVICE}" -- mkpart primary ntfs "${END2}GiB" "${END3}GiB"
        echo "### Creating Windows partition on ${DEVICE}..."
        parted -s -a optimal "${DEVICE}" -- mkpart primary ntfs "${END3}GiB" '100%'
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
