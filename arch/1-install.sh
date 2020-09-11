#!/bin/bash -e

HOSTNAME=$1
source "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/config.env

EFI_SIZE=${EFI_SIZE:-512MiB}
SWAP_SIZE=${SWAP_SIZE:-$(free --giga | grep \^Mem | awk '{print $2}')GiB}
KERNEL=${KERNEL:-linux}

VKEY_TYPE=${VKEY_TYPE:-efi} # efi|root|prompt
case ${VKEY_TYPE} in
    efi)
        VKEY_FILE=/sys/firmware/efi/efivars/keyfile-77fa9abd-0359-4d32-bd60-28f4e78f784b
        if [[ ! -f "${VKEY_FILE}" ]]
        then
            echo "### Creating EFI keyfile..."
            TMPFILE=$(mktemp)
            dd bs=1 count=28 if=/dev/urandom of="${TMPFILE}"
            efivar -n 77fa9abd-0359-4d32-bd60-28f4e78f784b-keyfile -t 7 -w -f "${TMPFILE}"
            rm "${TMPFILE}"
        fi
        ;;
    root|prompt)
        VKEY_FILE=/root/vkey
        ;;
    *)
        echo "Bad VKEY_TYPE: ${VKEY_TYPE}"
        exit 1
        ;;
esac
case ${VKEY_TYPE} in
    efi|prompt)
        SWAP_VKEY_FILE=${VKEY_FILE}
        ;;
    root)
        SWAP_VKEY_FILE=/dev/urandom
        ;;
esac

echo "### Creating root keyfile..."
dd bs=1 count=32 if=/dev/urandom of=/root/vkey

echo "### Adding packages..."
PACKAGES=(
    pacman-contrib
)
# pacman-key --recv-keys F75D9D76
# pacman-key --lsign-key F75D9D76
# cat << EOF >>/etc/pacman.conf

# [archzfs]
# Server = https://archzfs.com/\$repo/\$arch
# EOF
pacman -Sy --needed --noconfirm "${PACKAGES[@]}"

echo "### Cleaning up prior partitions..."
umount -R /target || true
zpool destroy z || true

EFI_DEVS=()
EFI_IDS=()
Z_DEVS=()
Z_IDS=()
SWAP_DEVS=()
SWAP_IDS=()

TABLE_TYPE="gpt"
for DEVICE in "${SYSTEM_DEVICES[@]}"
do
    echo "### Wiping and re-partitioning ${DEVICE}..."
    wipefs --all "${DEVICE}"
    parted -s "${DEVICE}" -- mklabel "${TABLE_TYPE}"
    while [ -L "${DEVICE}-part2" ] ; do : ; done
    parted -s "${DEVICE}" -- mkpart primary 0% "${EFI_SIZE}"
    parted -s "${DEVICE}" -- set 1 esp on
    parted -s "${DEVICE}" -- mkpart primary "${EFI_SIZE}" -"${SWAP_SIZE}"
    parted -s "${DEVICE}" -- mkpart primary -"${SWAP_SIZE}" 100%
    sleep 1
    EFI_DEVS+=("${DEVICE}-part1")
    EFI_IDS+=($(blkid ${DEVICE}-part1 -o value -s PARTUUID))
    Z_DEVS+=("${DEVICE}-part2")
    Z_IDS+=($(blkid ${DEVICE}-part2 -o value -s PARTUUID))
    SWAP_DEVS+=("${DEVICE}-part3")
    SWAP_IDS+=($(blkid ${DEVICE}-part3 -o value -s PARTUUID))
done

echo "### Creating zpool z... (${Z_DEVS[@]})"
ZPOOL_ARGS=(
    -o ashift=12
    -O acltype=posixacl
    -O relatime=on
    -O xattr=sa
    -O dnodesize=legacy
    -O normalization=formD
    -O aclinherit=passthrough
    -O com.sun:auto-snapshot=true

    -O compression=lz4
)
case ${VKEY_TYPE} in
    efi)
        ZPOOL_OPTS+=(
            -O encryption=aes-256-gcm
            -O keyformat=raw
            -O keylocation=file://${VKEY_FILE}
        )
        ;;
    prompt)
        ZPOOL_OPTS+=(
            -O encryption=aes-256-gcm
            -O keyformat=passphrase
            -O keylocation=prompt
        )
        ;;
    root)
        ;;
esac


zpool create -f "${ZPOOL_ARGS[@]}" -m none -R /target z ${SYSTEM_Z_TYPE} "${Z_DEVS[@]}"
zpool set cachefile=/etc/zfs/zpool.cache z
zfs create z/root
zpool set bootfs=z/root z
zfs create -o canmount=off -o com.sun:auto-snapshot=false z/root/var
zfs create z/root/var/cache
zfs create z/root/var/log
zfs create z/root/var/spool
zfs create z/root/var/tmp
zfs create -o mountpoint=/home z/home
zfs create -o mountpoint=/root z/home/root
[[ "${HAS_DOCKER}" == "1" ]] && zfs create -o mountpoint=/var/lib/docker z/docker
zfs create -o mountpoint=/var/volumes -o com.sun:auto-snapshot=true z/volumes
zfs create -o com.sun:auto-snapshot=false z/volumes/scratch
zfs create -o mountpoint=/var/lib/libvirt/images -o com.sun:auto-snapshot=true z/images
zfs create -o com.sun:auto-snapshot=false z/images/scratch

echo "### Formatting EFI partition(s)... (${EFI_DEVS[@]})"
for i in "${!EFI_DEVS[@]}"
do
    mkfs.fat -F 32 -n "EFI${i}" "${EFI_DEVS[$i]}"
done
mkdir -p "/target/efi"
mount "${EFI_DEVS[0]}" "/target/efi"
for (( i=1; i<${#EFI_DEVS[@]}; i++ ))
do
    mkdir -p "/target/efi.${i}"
    mount "${EFI_DEVS[$i]}" "/target/efi.${i}"
done

echo "### Setting up swap... (${SWAP_DEVS[@]})"
for i in "${!SWAP_DEVS[@]}"
do
    cryptsetup --cipher=aes-xts-plain64 --key-size=256 --key-file=${SWAP_VKEY_FILE} --allow-discards open --type plain "/dev/disk/by-partuuid/${SWAP_IDS[$i]}" swap${i}
    mkswap -L SWAP${i} /dev/mapper/swap${i}
done

echo "### Mounting tmp..."
mkdir -p /target/tmp
mount -t tmpfs tmpfs /target/tmp

echo "### Done partitioning!"
df -h
mount | grep target

# echo "### Updating Pacman mirrors..."
# curl -s "https://www.archlinux.org/mirrorlist/?country=US&protocol=https&use_mirror_status=on" | sed -e 's/^#Server/Server/' -e '/^#/d' | rankmirrors -n 5 - >/etc/pacman.d/mirrorlist

echo "### Pacstrapping..."
pacstrap /target base ${KERNEL} linux-firmware

echo "### Copying install files..."
mkdir -p /target/install
cp -rf "$(cd "$(dirname "$0")" ; pwd)"/* /target/install

echo "### Copying preset files..."
rsync -ar "$(cd "$(dirname "$0")" ; pwd)"/common/files/ /target
rsync -ar "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/files/ /target || true

echo "### Copying ZFS files..."
mkdir -p /target/etc/zfs
cp /etc/zfs/zpool.cache /target/etc/zfs/zpool.cache

echo "### Configuring openswap hook..."
echo "run_hook () {" >> /target/etc/initcpio/hooks/openswap
for i in "${!SWAP_DEVS[@]}"
do
    echo "cryptsetup --cipher=aes-xts-plain64 --key-size=256 --key-file=${SWAP_VKEY_FILE} --allow-discards open --type plain /dev/disk/by-partuuid/${SWAP_IDS[$i]} swap${i}" >> /target/etc/initcpio/hooks/openswap
done
echo "}" >> /target/etc/initcpio/hooks/openswap
cat << EOF >> /target/etc/initcpio/install/openswap
build ()
{
    add_runscript
}
help ()
{
    echo "Opens the swap encrypted partition(s)"
}
EOF

echo "### Configuring fstab..."
#genfstab -U /target >> /target/etc/fstab
#echo "z/root / zfs rw,noatime,xattr,noacl 0 0" >> /target/etc/fstab
echo "PARTUUID=${EFI_IDS[0]} /efi vfat rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,utf8,errors=remount-ro 0 2" >> /target/etc/fstab
for (( i=1; i<${#EFI_DEVS[@]}; i++ ))
do
    echo "PARTUUID=${EFI_IDS[$i]} /efi.${i} vfat rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,utf8,errors=remount-ro 0 2" >> /target/etc/fstab
done
for i in "${!SWAP_DEVS[@]}"
do
    echo "/dev/mapper/swap${i} none swap defaults,discard,pri=100 0 0" >> /target/etc/fstab
done
echo "tmpfs /tmp tmpfs rw,nodev,nosuid,relatime,size=${TMP_SIZE} 0 0" >> /target/etc/fstab

echo "### Copying root files..."
rsync -ar ~/.ssh/ /target/root/.ssh
rsync -ar ~/.secrets/ /target/root/.secrets
cp /root/vkey /target/root/vkey

echo "### Running further install in the chroot..."
arch-chroot /target /install/2-install-chroot.sh ${HOSTNAME}

echo "### Unmounting..."
umount -R /target
zfs unmount -a

echo "### Snapshotting..."
for pool in z/root
do
    zfs snapshot ${pool}@pre-boot-install
done

echo "### Exporting..."
zpool export z

echo "### Done installing! Rebooting..."
#reboot
