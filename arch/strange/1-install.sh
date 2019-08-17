#!/bin/sh
set -e

# System
SYSTEM_DEVICES=(
    ata-SanDisk_SDSSDX240GG25_130811402135
    ata-SanDisk_SDSSDX240GG25_131102400461
    ata-SanDisk_SDSSDX240GG25_131102401287
    ata-SanDisk_SDSSDX240GG25_131102402736
    )

echo "### Cleaning up prior partitions..."
umount /keys || true
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
    parted -s "${DEVICE}" -- mkpart primary 1024MiB 211GiB
    parted -s "${DEVICE}" -- mkpart primary 211GiB 100%
    BOOT_DEVS+=("${DEVICE}-part2")
    Z_DEVS+=("${DEVICE}-part3")
    SWAP_DEVS+=("${DEVICE}-part4")
done
sleep 1

echo "### Creating zpool boot..."
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
    boot raidz "${BOOT_DEVS[@]}"
zfs unmount -a
zpool export boot

echo "### Creating zpool z..."
mkdir -p /keys
mount -o ro "/dev/disk/by-label/KEYS" /keys

zpool create \
    -o ashift=12 \
    -O atime=off \
    -O compression=lz4 \
    -m none \
    -f \
    z raidz "${Z_DEVS[@]}"
zfs create z/root
# zfs create -o encryption=on -o keyformat=raw -o keylocation=file:///keys/13 z/root
zfs create -o canmount=off z/root/var
zfs create z/root/var/cache
zfs create z/root/var/log
zfs create z/root/var/spool
zfs create z/root/var/tmp
zfs create z/home
zfs create z/docker
# zfs create -o encryption=on -o keyformat=raw -o keylocation=file:///keys/13 z/home
# zfs create -o encryption=on -o keyformat=raw -o keylocation=file:///keys/13 z/docker
zfs unmount -a
zpool set bootfs=z/root z
zpool export z

umount /keys

echo "### Setting up swap..."
for i in "${!SWAP_DEVS[@]}"
do
    mkswap -L"SWAP${i}" "${SWAP_DEVS[$i]}"
done

# Bulk
# ata-WDC_WD60EFRX-68MYMN1_WD-WX11DA4DJ3CN

echo "### Done partitioning!"

echo "### Importing/mounting filesystems..."
mkdir -p /keys
mount -o ro /dev/disk/by-label/KEYS /keys
for d in /dev/disk/by-label/SWAP*
do
    swapon -p 100 "${d}"
done
mount -o remount,size=8G /run/archiso/cowspace

mkdir -p /target
zpool import -R /target -l z
zpool set cachefile=/etc/zfs/zpool.cache z
zfs set mountpoint=/ z/root
zfs set mountpoint=/home z/home
zfs set mountpoint=/var/lib/docker z/docker
zfs mount -a
mkdir -p /target/boot
zpool import -R /target boot
zpool set cachefile=/etc/zfs/zpool.cache boot
zfs set mountpoint=/boot boot
for i in 0 1 2 3
do
    mkdir -p "/target/efi/${i}"
    mount "/dev/disk/by-label/UEFI-${i}" "/target/efi/${i}"
done
mkdir -p /target/install
cp -rf "$(cd "$(dirname "$0")" ; pwd)"/* /target/install
umount /keys
mkdir -p /target/keys
mount -o ro /dev/disk/by-label/KEYS /target/keys
# zfs set keylocation=file:///boot/z.key z/root
# zfs set keylocation=file:///boot/z.key z/home
# zfs set keylocation=file:///boot/z.key z/docker
df -h
mount | grep target

echo "### Updating Pacman..."
pacman -Sy --needed --noconfirm pacman-contrib
curl -s "https://www.archlinux.org/mirrorlist/?country=US&protocol=https&use_mirror_status=on" | sed -e 's/^#Server/Server/' -e '/^#/d' | rankmirrors -n 5 - >/etc/pacman.d/mirrorlist

echo "### Pacstrapping..."
pacstrap /target base

#genfstab -U /target >> /target/etc/fstab
cat <<EOF >>/target/etc/fstab
LABEL=KEYS       	/keys  	ext2      	ro,relatime	0 2

z/root              	/         	zfs       	rw,noatime,xattr,noacl	0 0

LABEL=UEFI-0        	/efi/0    	vfat      	rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,utf8,errors=remount-ro	0 2
LABEL=UEFI-1        	/efi/1    	vfat      	rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,utf8,errors=remount-ro	0 2
LABEL=UEFI-2        	/efi/2    	vfat      	rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,utf8,errors=remount-ro	0 2
LABEL=UEFI-3        	/efi/3    	vfat      	rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,utf8,errors=remount-ro	0 2

/dev/disk/by-label/SWAP0 	none      	swap      	defaults,pri=100  	0 0
/dev/disk/by-label/SWAP1 	none      	swap      	defaults,pri=100  	0 0
/dev/disk/by-label/SWAP2 	none      	swap      	defaults,pri=100  	0 0
/dev/disk/by-label/SWAP3 	none      	swap      	defaults,pri=100  	0 0
EOF

mkdir -p /target/etc/zfs
cp /etc/zfs/zpool.cache /target/etc/zfs/zpool.cache

mkdir -p /target/etc/zsh
cp /etc/zsh/* /target/etc/zsh

echo "### Running further install in the chroot..."
arch-chroot /target /install/1.1-install-chroot.sh

echo "### Unmounting..."
umount -R /target
zfs unmount -a

zfs snapshot boot@install
zfs snapshot z@install

zpool export boot
zpool export z

echo "### Done installing! Rebooting..."
reboot
