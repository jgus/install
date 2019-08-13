#!/bin/sh
set -e

mkdir -p /target
mount /dev/system/z0 /target
mkdir -p /target/boot
mount /dev/system/boot /target/boot
mkdir -p /target/efi/0
mount /dev/disk/by-id/ata-SanDisk_SDSSDX240GG25_130811402135-part1 /target/efi/0
mkdir -p /target/efi/1
mount /dev/disk/by-id/ata-SanDisk_SDSSDX240GG25_131102400461-part1 /target/efi/1
mkdir -p /target/efi/2
mount /dev/disk/by-id/ata-SanDisk_SDSSDX240GG25_131102401287-part1 /target/efi/2
mkdir -p /target/efi/3
mount /dev/disk/by-id/ata-SanDisk_SDSSDX240GG25_131102402736-part1 /target/efi/3
mkdir -p /target/install
mount --bind "$(cd "$(dirname "$0")" ; pwd)" /target/install

pacman -Sy --noconfirm pacman-contrib
curl -s "https://www.archlinux.org/mirrorlist/?country=US&protocol=https&use_mirror_status=on" | sed -e 's/^#Server/Server/' -e '/^#/d' | rankmirrors -n 5 - >/etc/pacman.d/mirrorlist
cat <<EOF >>/etc/pacman.conf

[multilib]
Include = /etc/pacman.d/mirrorlist
EOF
pacman -Syy

pacstrap /target base 

genfstab -U /target >> /target/etc/fstab

arch-chroot /target /install/install-chroot.sh

umount /target/install
rm -rf /target/install
umount -R /target
