#!/bin/sh
set -e

HOSTNAME=$1
source "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/config.env

# System
echo "### Cleaning up prior partitions..."
umount -R /target || true
for i in /dev/disk/by-label/SWAP*
do
    swapoff "${i}" || true
done
zpool destroy boot || true
zpool destroy z || true
zpool destroy bulk || true

EFI_DEVS=()
BOOT_DEVS=()
Z_DEVS=()
SWAP_DEVS=()
for i in "${!SYSTEM_DEVICES[@]}"
do
    DEVICE="/dev/disk/by-id/${SYSTEM_DEVICES[$i]}"
    echo "### Wiping and re-partitioning ${DEVICE}..."
    wipefs --all "${DEVICE}"
    parted -s "${DEVICE}" -- mklabel gpt
    while [ -L "${DEVICE}-part2" ] ; do : ; done
    parted -s "${DEVICE}" -- mkpart primary 4MiB 512MiB
    parted -s "${DEVICE}" -- set 1 esp on
    parted -s "${DEVICE}" -- mkpart primary 512MiB 1024MiB
    parted -s "${DEVICE}" -- mkpart primary 1024MiB "${Z_PART_END}"
    parted -s "${DEVICE}" -- mkpart primary "${Z_PART_END}" 100%
    EFI_DEVS+=("${DEVICE}-part1")
    BOOT_DEVS+=("${DEVICE}-part2")
    Z_DEVS+=("${DEVICE}-part3")
    SWAP_DEVS+=("${DEVICE}-part4")
done
sleep 1

echo "### Formatting EFI partitions... (${EFI_DEVS[@]})"
for i in "${!EFI_DEVS[@]}"
do
    mkfs.fat -F 32 -n "UEFI${i}" "${EFI_DEVS[$i]}"
done

echo "### Creating zpool boot... (${BOOT_DEVS[@]})"
zpool create \
    -d \
    -o feature@allocation_classes=enabled \
    -o feature@async_destroy=enabled      \
    -o feature@bookmarks=enabled          \
    -o feature@embedded_data=enabled      \
    -o feature@empty_bpobj=enabled        \
    -o feature@enabled_txg=enabled        \
    -o feature@extensible_dataset=enabled \
    -o feature@filesystem_limits=enabled  \
    -o feature@hole_birth=enabled         \
    -o feature@large_blocks=enabled       \
    -o feature@lz4_compress=enabled       \
    -o feature@project_quota=enabled      \
    -o feature@resilver_defer=enabled     \
    -o feature@spacemap_histogram=enabled \
    -o feature@spacemap_v2=enabled        \
    -o feature@userobj_accounting=enabled \
    -o feature@zpool_checkpoint=enabled   \
    -o ashift=12 \
    -O atime=off \
    -O compression=lz4 \
    -m none \
    -f \
    boot ${SYSTEM_Z_TYPE} "${BOOT_DEVS[@]}"
zfs unmount -a
zpool export boot

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
    mkswap -L"SWAP${i}" "${SWAP_DEVS[$i]}"
done

# Bulk
if [[ "${BULK_DEVICE}" != "" ]]
then
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
        bulk "${BULK_DEVICE}"
    zfs unmount -a
    zpool export bulk
fi

echo "### Done partitioning!"

echo "### Importing/mounting filesystems..."
for d in /dev/disk/by-label/SWAP*
do
    swapon -p 100 "${d}"
done
mount -o remount,size=8G /run/archiso/cowspace

mkdir -p /target
zpool import -R /target -l z
zpool set cachefile=/etc/zfs/zpool.cache z
zfs set mountpoint=/ z/root
zfs mount -a
mkdir -p /target/boot
zpool import -R /target boot
zpool set cachefile=/etc/zfs/zpool.cache boot
zfs set mountpoint=/boot boot
if [[ "${BULK_DEVICE}" != "" ]]
then
    mkdir -p /target/bulk
    zpool import -R /target -l bulk
    zpool set cachefile=/etc/zfs/zpool.cache bulk
    zfs set mountpoint=/bulk bulk
fi
for i in "${!EFI_DEVS[@]}"
do
    mkdir -p "/target/efi/${i}"
    mount "/dev/disk/by-label/UEFI${i}" "/target/efi/${i}"
done
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
pacstrap /target base linux-zen dhcpcd openresolv

echo "### Copying preset files..."
rsync -ar "$(cd "$(dirname "$0")" ; pwd)"/common/files/ /target
rsync -ar "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/files/ /target

echo "### Configuring fstab..."
#genfstab -U /target >> /target/etc/fstab
echo "z/root / zfs rw,noatime,xattr,noacl 0 0" >> /target/etc/fstab
for i in "${!EFI_DEVS[@]}"
do
    echo "LABEL=UEFI${i} /efi/${i} vfat rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,utf8,errors=remount-ro 0 2" >> /target/etc/fstab
done
for i in "${!SWAP_DEVS[@]}"
do
    echo "swap${i} ${SWAP_DEVS[i]} /dev/urandom swap,cipher=aes-xts-plain64,size=256" >>/target/etc/crypttab
    echo "/dev/mapper/swap${i} none swap defaults,pri=100 0 0" >> /target/etc/fstab
done
echo "tmpfs /tmp tmpfs rw,nodev,nosuid,relatime,size=${TMP_SIZE} 0 0" >> /target/etc/fstab

echo "### Copying ZFS files..."
mkdir -p /target/etc/zfs
cp /etc/zfs/zpool.cache /target/etc/zfs/zpool.cache

echo "### Copying NVRAM-stored files..."
"$(cd "$(dirname "$0")" ; pwd)/read-secrets.sh" /target/tmp/machine-secrets
rsync -ar /target/tmp/machine-secrets/files/ /target || true

echo "### Running further install in the chroot..."
arch-chroot /target /install/1.1-install-chroot.sh ${HOSTNAME}

echo "### Unmounting..."
umount -R /target
zfs unmount -a

echo "### Snapshotting..."
for pool in boot z/root
do
    zfs snapshot ${pool}@pre-boot-install
done

echo "### Exporting..."
zpool export boot
zpool export z
if [[ "${BULK_DEVICE}" != "" ]]
then
    zpool export bulk
fi

echo "### Done installing! Rebooting..."
reboot
