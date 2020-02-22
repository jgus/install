#!/bin/bash
set -e

HOSTNAME=$1
source "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/config.env

lscpu | grep GenuineIntel && HAS_INTEL_CPU=1
lscpu | grep AuthenticAMD && HAS_AMD_CPU=1

KERNEL=${KERNEL:-generic}

BOOT_PACKAGES=(
    grub-efi shim
    linux-${KERNEL} linux-headers-${KERNEL} linux-image-${KERNEL}
    zfsutils-linux zfs-initramfs
    cryptsetup
    zsh
    nano
    man
    ssh
    curl
    locales
    git
)
[[ "${HAS_INTEL_CPU}" == "1" ]] && BOOT_PACKAGES+=(intel-microcode)
[[ "${HAS_AMD_CPU}" == "1" ]] && BOOT_PACKAGES+=(amd64-microcode)
# TODO

# Password
cat <<EOF | passwd
changeme
changeme
EOF

echo "### Installing pacakages..."
#/etc/apt/sources.list
#ln -s /proc/self/mounts /etc/mtab
apt update
apt install --yes "${BOOT_PACKAGES[@]}"

echo "### Configuring clock..."
ln -sf "/usr/share/zoneinfo/${TIME_ZONE}" /etc/localtime
hwclock --systohc

echo "### Configuring locale..."
echo "en_US.UTF-8 UTF-8" >>/etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >/etc/locale.conf

echo "### Configuring hostname..."
echo "${HOSTNAME}" >/etc/hostname
cat <<EOF >/etc/hosts
127.0.0.1 localhost
::1 localhost
127.0.1.1 ${HOSTNAME}.gustafson.me ${HOSTNAME}
EOF

# echo "### Root opt install..."
# /root/opt/install.sh

echo "### Configuring network..."

echo "### Enabling SSH..."
systemctl enable ssh

echo "### Generating ZFS cache..."
zfs load-key -a
zpool set cachefile=/etc/zfs/zpool.cache root
if [[ -d /bulk ]]
then
    zpool set cachefile=/etc/zfs/zpool.cache bulk
fi

echo "### Configuring VFIO..."
if [[ "${VFIO_IDS}" != "" ]]
then
    echo "options vfio_pci ids=${VFIO_IDS}" >> /etc/modprobe.d/vfio.conf
fi

echo "### /tmp..."
cp /usr/share/systemd/tmp.mount /etc/systemd/system/
systemctl enable tmp.mount

echo "### Configuring boot image..."
update-initramfs -u -k all

echo "### Installing bootloader..."
update-grub
grub-install --efi-directory=/boot/efi --bootloader-id=ubuntu --recheck --no-floppy

echo "### Configuring nVidia updates..."
#/etc/pacman.d/hooks/nvidia.hook

echo "### Configuring Zsh..."
chsh -s /bin/zsh
