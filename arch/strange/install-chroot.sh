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

# Packages
cat <<EOF >>/etc/pacman.conf

[multilib]
Include = /etc/pacman.d/mirrorlist

[archzfs]
Server = https://archzfs.com/\$repo/\$arch
EOF
pacman-key -r F75D9D76
pacman-key --lsign-key F75D9D76
PACKAGES=(
    # General
    base-devel git zsh
    # Drivers
    nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings
    # Bootloader
    intel-ucode grub efibootmgr
    # RNG
    rng-tools
    # OpenSSH
    openssh
    # Xorg
    xorg
    # LightDM
    lightdm lightdm-gtk-greeter
    # KDE
    plasma-meta kde-applications-meta xdg-user-dirs
    # Applications
    # google-chrome vlc ffmpeg-full
)
pacman -Syyu --needed --noconfirm "${PACKAGES[@]}"

# Initramfs
sed -i 's/MODULES=(\(.*\))/MODULES=(\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/g' /etc/mkinitcpio.conf
sed -i 's/HOOKS=(\(.*\)block filesystems keyboard\(.*\))/HOOKS=(\1block lvm2 keyboard zfs filesystems\2)/g' /etc/mkinitcpio.conf
mkinitcpio -p linux-zen

# Bootloader
export ZPOOL_VDEV_NAME_PATH=1
for  i in 3 2 1 0
do
    grub-install --target=x86_64-efi --efi-directory="/efi/${i}" --bootloader-id="GRUB-${i}"
done
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 nvidia-drm.modeset=1"/g' /etc/default/grub
sed -i 's/GRUB_PRELOAD_MODULES="\(.*\)"/GRUB_PRELOAD_MODULES="\1 lvm"/g' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

# RNG
systemctl enable rngd.service

# SSH
echo "PasswordAuthentication no" >>/etc/ssh/sshd_config
systemctl enable sshd.socket
mkdir -p /root/.ssh
curl https://github.com/jgus.keys >> /root/.ssh/authorized_keys
chmod 400 /root/.ssh/authorized_keys

# Xorg
#cp /usr/share/X11/xorg.conf.d/* /etc/X11/xorg.conf.d/
#nvidia-xconfig
cat <<EOF >/etc/X11/xorg.conf
# nvidia-xconfig: X configuration file generated by nvidia-xconfig
# nvidia-xconfig:  version 430.40

Section "ServerLayout"
    Identifier     "Layout0"
    Screen      0  "Screen0"
    InputDevice    "Keyboard0" "CoreKeyboard"
    InputDevice    "Mouse0" "CorePointer"
EndSection

Section "Files"
EndSection

Section "InputDevice"
    # generated from default
    Identifier     "Mouse0"
    Driver         "mouse"
    Option         "Protocol" "auto"
    Option         "Device" "/dev/psaux"
    Option         "Emulate3Buttons" "no"
    Option         "ZAxisMapping" "4 5"
EndSection

Section "InputDevice"
    # generated from default
    Identifier     "Keyboard0"
    Driver         "kbd"
EndSection

Section "Monitor"
    Identifier     "Monitor0"
    VendorName     "Unknown"
    ModelName      "Unknown"
    Option         "DPMS"
EndSection

Section "Device"
    Identifier     "Device0"
    Driver         "nvidia"
    VendorName     "NVIDIA Corporation"
EndSection

Section "Screen"
    Identifier     "Screen0"
    Device         "Device0"
    Monitor        "Monitor0"
    DefaultDepth    24
    SubSection     "Display"
        Depth       24
    EndSubSection
EndSection
EOF

# LightDM
systemctl enable lightdm.service

# Password
cat <<EOF
#####
#
# Please enter a root password:
#
#####
EOF
passwd

cp "$(cd "$(dirname "$0")" ; pwd)/first-boot.sh" /root/first-boot.sh

# TODO
# ZFS encryption
# ZFS autostart
# NVIDIA kernel hook
# ZFS scrub
# ZFS snapshots/replication
# Set default shell
# add users
# Sync
# Steam
# Wine?
# Multiseat
