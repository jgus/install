#!/bin/bash
set -e

HOSTNAME=$1
source "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/config.env

lscpu | grep GenuineIntel && HAS_INTEL_CPU=1
lscpu | grep AuthenticAMD && HAS_AMD_CPU=1

KERNEL=${KERNEL:-linux}

BOOT_PACKAGES=(
    linux-generic linux-headers-generic linux-image-generic
    zfsutils-linux zfs-initramfs
    cryptsetup
    zsh
    network-manager
    ssh
    curl
    locales
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
ln -s /proc/self/mounts /etc/mtab
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
sed -i "s|managed=.*|managed=true|g" /etc/NetworkManager/NetworkManager.conf

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

# echo "### Configuring boot image..."
# # Nothing to do!

echo "### Installing bootloader..."
# /etc/kernel/postinst.d/bootctl
KERNEL_PARAMS="${KERNEL_PARAMS} loglevel=3 root=ZFS:root/root rw"
if [[ "${VFIO_IDS}" != "" ]]
then
    [[ "${HAS_INTEL_CPU}" == "1" ]] && KERNEL_PARAMS="${KERNEL_PARAMS} intel_iommu=on"
    # TODO AMD
    KERNEL_PARAMS="${KERNEL_PARAMS} iommu=pt"
fi
[[ "${HAS_NVIDIA}" == "1" ]] && KERNEL_PARAMS="${KERNEL_PARAMS} nvidia-drm.modeset=1"
[[ "${ALLOW_SUSPEND}" == "1" ]] && KERNEL_PARAMS="${KERNEL_PARAMS} resume=/dev/mapper/swap0"
bootctl --path=/boot install
mkdir -p /boot/loader
mkdir -p /boot/loader/entries
echo "default ubuntu" >/boot/loader/loader.conf
sed -i "s|^options*$|options ${KERNEL_PARAMS}|g" /boot/loader/entries/ubuntu.conf
update-initramfs -u -k all

echo "### Configuring nVidia updates..."
#/etc/pacman.d/hooks/nvidia.hook

echo "### Configuring Zsh..."
chsh -s /bin/zsh

echo "### Preparing post-boot install..."
#/etc/systemd/system/getty@tty1.service.d/override.conf
#/root/.zlogin
#/root/.runonce.sh
chmod a+x ~/.runonce.sh
