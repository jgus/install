do_partition() {
    WINDOWS_SIZE=196GiB    
    for DEVICE in "${SYSTEM_DEVICES[@]}"
    do
        echo "### Wiping and re-partitioning ${DEVICE}..."
        blkdiscard -f "${DEVICE}" || true
        wipefs -af "${DEVICE}"
        parted -s "${DEVICE}" -- mklabel gpt
        while [ -L "${DEVICE}-part2" ] ; do : ; done
        parted -s --align=opt "${DEVICE}" -- mkpart primary 0% "${BOOT_SIZE}"
        parted -s "${DEVICE}" -- set 1 esp on
        parted -s --align=opt "${DEVICE}" -- mkpart primary "${BOOT_SIZE}" "${WINDOWS_SIZE}"
        parted -s --align=opt "${DEVICE}" -- mkpart primary "${WINDOWS_SIZE}" -"${SWAP_SIZE}"
        parted -s --align=opt "${DEVICE}" -- mkpart primary -"${SWAP_SIZE}" 100%
        sleep 1
        BOOT_DEVS+=("${DEVICE}-part1")
        BOOT_IDS+=($(blkid ${DEVICE}-part1 -o value -s PARTUUID))
        Z_DEVS+=("${DEVICE}-part3")
        Z_IDS+=($(blkid ${DEVICE}-part3 -o value -s PARTUUID))
        SWAP_DEVS+=("${DEVICE}-part4")
        SWAP_IDS+=($(blkid ${DEVICE}-part4 -o value -s PARTUUID))
    done
    BOOT_DEVS=("${SYSTEM_DEVICES[0]}-part1")
    BOOT_IDS=($(blkid ${SYSTEM_DEVICES[0]}-part1 -o value -s PARTUUID))
}
