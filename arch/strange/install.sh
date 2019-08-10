#!/bin/sh
set -e

mkdir -p /target
mount /dev/system/z0 /target
mkdir -p /target/boot
mount /dev/system/boot /target/boot
mkdir -p /target/install
mount --bind "$(cd "$(dirname "$0")" ; pwd)" /target/install

pacman -Sy --noconfirm pacman-contrib
curl -s "https://www.archlinux.org/mirrorlist/?country=US&protocol=https&use_mirror_status=on" | sed -e 's/^#Server/Server/' -e '/^#/d' | rankmirrors -n 5 - >/etc/pacman.d/mirrorlist
pacman -Syy

pacstrap /target base base-devel intel-ucode grub

genfstab /target >> /target/etc/fstab

arch-chroot /target /install/install-chroot.sh

umount /target/install
rm -rf /target/install
umount -R /target
