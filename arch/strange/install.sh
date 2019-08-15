#!/bin/sh
set -e

umount -R /target || true
umount /keyfile || true

echo "Importing/mounting filesystems..."
mkdir -p /keyfile
mount -o ro /dev/disk/by-label/KEYFILE /keyfile
for i in 0 1 2 3
do
    cryptsetup --key-file=/keyfile/system open "/dev/disk/by-label/lockedz${i}" "z${i}"
done
for d in /dev/disk/by-label/SWAP*
do
    swapon -p 0 "${d}"
done
mount -o remount,size=8G /run/archiso/cowspace

mkdir -p /target
zpool import -R /target z
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
mount --bind "$(cd "$(dirname "$0")" ; pwd)" /target/install
umount /keyfile
mkdir -p /target/keyfile
mount -o ro /dev/disk/by-label/KEYFILE /target/keyfile
df -h
mount | grep target

echo "Updating Pacman..."
pacman -Sy --needed --noconfirm pacman-contrib
curl -s "https://www.archlinux.org/mirrorlist/?country=US&protocol=https&use_mirror_status=on" | sed -e 's/^#Server/Server/' -e '/^#/d' | rankmirrors -n 5 - >/etc/pacman.d/mirrorlist

echo "Pacstrapping..."
pacstrap /target base linux-zen linux-zen-headers dkms zfs-linux-zen

#genfstab -U /target >> /target/etc/fstab
cat <<EOF >>/target/etc/fstab
z/root              	/         	zfs       	rw,noatime,xattr,noacl	0 0

LABEL=UEFI-0        	/efi/0    	vfat      	rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,utf8,errors=remount-ro	0 2
LABEL=UEFI-1        	/efi/1    	vfat      	rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,utf8,errors=remount-ro	0 2
LABEL=UEFI-2        	/efi/2    	vfat      	rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,utf8,errors=remount-ro	0 2
LABEL=UEFI-3        	/efi/3    	vfat      	rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,utf8,errors=remount-ro	0 2

LABEL=KEYFILE       	/keyfile  	ext2      	ro,relatime	0 2

/dev/mapper/swapvg-swap 	none      	swap      	defaults  	0 0
EOF

cp /etc/zfs/zpool.cache /target/etc/zfs/zpool.cache

echo "Running further install in the chroot..."
arch-chroot /target /install/install-chroot.sh

echo "Unmounting..."
umount /target/install
rm -rf /target/install
umount -R /target
zfs unmount -a

zfs snapshot -r boot@install
zfs snapshot -r z@install

zpool export boot
zpool export z

echo "Done installing!"
