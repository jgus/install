#!/bin/sh
set -e

umount -R /target || true
swapoff /dev/system/swap || true

mkfs.ext4 /dev/system/boot
mkfs.ext4 /dev/system/z0
mkswap /dev/system/swap
swapon /dev/system/swap

mkdir -p /target
mount /dev/system/z0 /target
mkdir -p /target/boot
mount /dev/system/boot /target/boot
for i in 0 1 2 3
do
    mkdir -p "/target/efi/${i}"
    mount "/dev/disk/by-label/UEFI-${i}" "/target/efi/${i}"
done
mkdir -p /target/install
mount --bind "$(cd "$(dirname "$0")" ; pwd)" /target/install

pacman -Sy --noconfirm pacman-contrib
curl -s "https://www.archlinux.org/mirrorlist/?country=US&protocol=https&use_mirror_status=on" | sed -e 's/^#Server/Server/' -e '/^#/d' | rankmirrors -n 5 - >/etc/pacman.d/mirrorlist
cat <<EOF >>/etc/pacman.conf

[multilib]
Include = /etc/pacman.d/mirrorlist
EOF
pacman -Syy

pacstrap /target base linux-zen linux-zen-headers dkms

genfstab -U /target >> /target/etc/fstab

arch-chroot /target /install/install-chroot.sh

umount /target/install
rm -rf /target/install
umount -R /target
