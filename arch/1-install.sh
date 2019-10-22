#!/bin/sh
set -e

HOSTNAME=$1
BOOT_SIZE=512MiB
source "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/config.env

BOOT_MODE=${BOOT_MODE:-efi}
KERNEL=${KERNEL:-linux}

# System
echo "### Cleaning up prior partitions..."
umount -R /target || true
for i in /dev/disk/by-label/SWAP*
do
    swapoff "${i}" || true
done
zpool destroy boot || true
zpool destroy z || true

BOOT_DEVS=()
Z_DEVS=()
SWAP_DEVS=()
TABLE_TYPE="gpt"
[[ "${BOOT_MODE}" == "bios" ]] && TABLE_TYPE="msdos"
for i in "${!SYSTEM_DEVICES[@]}"
do
    DEVICE="/dev/disk/by-id/${SYSTEM_DEVICES[$i]}"
    echo "### Wiping and re-partitioning ${DEVICE}..."
    wipefs --all "${DEVICE}"
    parted -s "${DEVICE}" -- mklabel "${TABLE_TYPE}"
    while [ -L "${DEVICE}-part2" ] ; do : ; done
    parted -s "${DEVICE}" -- mkpart primary 4MiB "${BOOT_SIZE}"
    [[ "${BOOT_MODE}" == "efi" ]] && parted -s "${DEVICE}" -- set 1 esp on
    parted -s "${DEVICE}" -- mkpart primary "${BOOT_SIZE}" "${Z_PART_END}"
    parted -s "${DEVICE}" -- mkpart primary "${Z_PART_END}" 100%
    BOOT_DEVS+=("${DEVICE}-part1")
    Z_DEVS+=("${DEVICE}-part2")
    SWAP_DEVS+=("${DEVICE}-part3")
done
sleep 1

echo "### Formatting boot partitions... (${BOOT_DEVS[@]})"
for i in "${!BOOT_DEVS[@]}"
do
    mkfs.fat -F 32 -n "BOOT${i}" "${BOOT_DEVS[$i]}"
done

echo "### Creating zpool z... (${Z_DEVS[@]})"
zpool create \
    -o ashift=12 \
    -O atime=off \
    -O compression=lz4 \
    -O encryption=on \
    -O keyformat=raw \
    -O keylocation=file:///sys/firmware/efi/efivars/keyfile-77fa9abd-0359-4d32-bd60-28f4e78f784b \
    -O aclinherit=passthrough \
    -O acltype=posixacl \
    -O xattr=sa \
    -m none \
    -f \
    z ${SYSTEM_Z_TYPE} "${Z_DEVS[@]}"
zfs create z/root
zfs create -o canmount=off z/root/var
zfs create z/root/var/cache
zfs create z/root/var/log
zfs create z/root/var/spool
zfs create z/root/var/tmp
zfs unmount -a
zpool set bootfs=z/root z
zpool export z

echo "### Setting up swap... (${SWAP_DEVS[@]})"
for i in "${!SWAP_DEVS[@]}"
do
    cryptsetup --cipher=aes-xts-plain64 --key-size=256 --key-file=/sys/firmware/efi/efivars/keyfile-77fa9abd-0359-4d32-bd60-28f4e78f784b --allow-discards open --type plain "${SWAP_DEVS[$i]}" swap${i}
    mkswap -L SWAP${i} /dev/mapper/swap${i}
    swapon -p 100 /dev/mapper/swap${i}
done
mount -o remount,size=8G /run/archiso/cowspace

# Bulk
if [[ "${BULK_DEVICE}" != "" ]]
then
    zpool import -l bulk || zpool create \
        -o ashift=12 \
        -O atime=off \
        -O compression=lz4 \
        -O encryption=on \
        -O keyformat=raw \
        -O keylocation=file:///sys/firmware/efi/efivars/keyfile-77fa9abd-0359-4d32-bd60-28f4e78f784b \
        -O aclinherit=passthrough \
        -O acltype=posixacl \
        -O xattr=sa \
        -m none \
        -f \
        bulk "${BULK_DEVICE}"
    zfs unmount -a
    zpool export bulk
fi

echo "### Done partitioning!"

echo "### Importing/mounting filesystems..."
mkdir -p /target
zpool import -R /target -l z
zpool set cachefile=/etc/zfs/zpool.cache z
zfs set mountpoint=/ z/root
zfs mount -a
if [[ "${BULK_DEVICE}" != "" ]]
then
    mkdir -p /target/bulk
    zpool import -R /target -l bulk
    zpool set cachefile=/etc/zfs/zpool.cache bulk
    zfs set mountpoint=/bulk bulk
fi
mkdir -p "/target/boot"
mount "/dev/disk/by-label/BOOT0" "/target/boot"
mkdir -p /target/install
cp -rf "$(cd "$(dirname "$0")" ; pwd)"/* /target/install
mkdir -p /target/tmp
mount -t tmpfs tmpfs /target/tmp

df -h
mount | grep target

echo "### Updating Pacman..."
pacman -Sy --needed --noconfirm pacman-contrib
curl -s "https://www.archlinux.org/mirrorlist/?country=US&protocol=https&use_mirror_status=on" | sed -e 's/^#Server/Server/' -e '/^#/d' | rankmirrors -n 5 - >/etc/pacman.d/mirrorlist

echo "### Pacstrapping..."
pacstrap /target base ${KERNEL} openresolv networkmanager dhclient

echo "### Copying preset files..."
rsync -ar "$(cd "$(dirname "$0")" ; pwd)"/common/files/ /target
rsync -ar "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/files/ /target

echo "### Configuring openswap hook..."
echo "run_hook () {" >> /target/etc/initcpio/hooks/openswap
for i in "${!SWAP_DEVS[@]}"
do
    echo "cryptsetup --cipher=aes-xts-plain64 --key-size=256 --key-file=/sys/firmware/efi/efivars/keyfile-77fa9abd-0359-4d32-bd60-28f4e78f784b --allow-discards open --type plain ${SWAP_DEVS[$i]} swap${i}" >> /target/etc/initcpio/hooks/openswap
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
echo "z/root / zfs rw,noatime,xattr,noacl 0 0" >> /target/etc/fstab
echo "LABEL=BOOT0 /boot vfat rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,utf8,errors=remount-ro 0 2" >> /target/etc/fstab
for i in "${!SWAP_DEVS[@]}"
do
    echo "/dev/mapper/swap${i} none swap defaults,discard,pri=100 0 0" >> /target/etc/fstab
done
echo "tmpfs /tmp tmpfs rw,nodev,nosuid,relatime,size=${TMP_SIZE} 0 0" >> /target/etc/fstab

echo "### Copying ZFS files..."
mkdir -p /target/etc/zfs
cp /etc/zfs/zpool.cache /target/etc/zfs/zpool.cache

echo "### Copying NVRAM-stored files..."
"$(cd "$(dirname "$0")" ; pwd)/read-secrets.sh" /target/tmp/machine-secrets
rsync -ar /target/tmp/machine-secrets/files/ /target || true

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
if [[ "${BULK_DEVICE}" != "" ]]
then
    zpool export bulk
fi

echo "### Done installing! Rebooting..."
reboot
