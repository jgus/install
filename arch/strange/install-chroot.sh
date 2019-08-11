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

# Network
systemctl enable dhcpcd.service

# Password
cat <<EOF
#####
#
# Please enter a root password:
#
#####
EOF
passwd

# SSH
echo "PasswordAuthentication no" >>/etc/ssh/sshd_config
systemctl enable sshd.socket
mkdir -p /root/.ssh
curl https://github.com/jgus.keys >> /root/.ssh/authorized_keys
chmod 400 /root/.ssh/authorized_keys

# Packages
cat <<EOF >>/etc/pacman.conf

[multilib]
Include = /etc/pacman.d/mirrorlist
EOF
pacman -Syu --noconfirm

# Initramfs
sed -i 's/MODULES=(\(.*\))/MODULES=(\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/g' /etc/mkinitcpio.conf
sed -i 's/HOOKS=(\(.*\)block filesystems\(.*\))/HOOKS=(\1block lvm2 filesystems\2)/g' /etc/mkinitcpio.conf
mkinitcpio -p linux

# Bootloader
# for s in 130811402135 131102400461 131102401287 131102402736
# do
#     DEVICE=/dev/disk/by-id/ata-SanDisk_SDSSDX240GG25_${s}
#     grub-install --target=i386-pc "${DEVICE}"
# done
for  i in 0 1 2 3
do
    grub-install --target=x86_64-efi --efi-directory=/efi/${i} --bootloader-id=GRUB-${i}
done
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 nvidia-drm.modeset=1"/g' /etc/default/grub
sed -i 's/GRUB_PRELOAD_MODULES="\(.*\)"/GRUB_PRELOAD_MODULES="\1 lvm"/g' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg
