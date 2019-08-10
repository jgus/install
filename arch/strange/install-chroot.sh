#!/bin/sh
set -e

# Time
ln -sf /usr/share/zoneinfo/America/Denver /etc/localtime
hwclock --systohc

# Locale
echo "en_US.UTF-8 UTF-8" >>/etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >/etc/locale.conf

# Hostmane
HOSTNAME=strange
echo "${HOSTNAME}" >/etc/hostname
cat <<EOF >/etc/hosts
127.0.0.1 localhost
::1 localhost
127.0.1.1 ${HOSTNAME}.localdomain ${HOSTNAME}
EOF

# Password
cat <<EOF
#####
#
# Please enter a root password:
#
#####
EOF
passwd

# Initramfs
sed -i 's/HOOKS=(\(.*\)block filesystems\(.*\))/HOOKS=(\1block lvm2 filesystems\2)/g' /etc/mkinitcpio.conf
mkinitcpio -p linux

# Bootloader
for s in 130811402135 131102400461 131102401287 131102402736
do
    DEVICE=/dev/disk/by-id/ata-SanDisk_SDSSDX240GG25_${s}
    grub-install --target=i386-pc "${DEVICE}"
done
sed -i 's/GRUB_PRELOAD_MODULES="\(.*\)"/GRUB_PRELOAD_MODULES="\1 lvm"/g' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg
