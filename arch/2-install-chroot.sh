#!/bin/sh
set -e

HOSTNAME=$1
source "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/config.env

KERNEL=${KERNEL:-linux}

BOOT_PACKAGES=(
    # Base
    diffutils logrotate man-db man-pages nano netctl usbutils vi which
    # Kernel
    ${KERNEL}-headers linux-firmware dkms base-devel
    # Bootloader
    intel-ucode efibootmgr
    # Firmware
    fwupd
    # ZFS
    zfs-dkms
    # Network
    openresolv networkmanager dhclient
    # ZSH
    zsh grml-zsh-config
    # LDAP Auth
    openldap nss-pam-ldapd sssd
    )
[[ "${HAS_NVIDIA}" == "1" ]] && BOOT_PACKAGES+=(
    nvidia-dkms
     )

# Password
cat <<EOF | passwd
changeme
changeme
EOF

/root/opt/install.sh

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
127.0.1.1 ${HOSTNAME}.localdomain ${HOSTNAME}
EOF

echo "### Installing pacakages..."
sed -i "s|#Color|Color|g" /etc/pacman.conf
cat <<EOF >>/etc/pacman.conf

[multilib]
Include = /etc/pacman.d/mirrorlist

[archzfs]
Server = https://archzfs.com/\$repo/\$arch

[repo-ck]
Server = http://repo-ck.com/\$arch
EOF
pacman-key -r F75D9D76
pacman-key --lsign-key F75D9D76
pacman-key -r 5EE46C4C
pacman-key --lsign-key 5EE46C4C
rsync -arP root@loki:/var/cache/pacman/pkg/ /var/cache/pacman/pkg || true
pacman -Syyu --needed --noconfirm "${BOOT_PACKAGES[@]}"

echo "### Configuring network..."
systemctl enable NetworkManager.service

echo "### Configuring VFIO..."
if [[ "${VFIO_IDS}" != "" ]]
then
    echo "options vfio_pci ids=${VFIO_IDS}" >> /etc/modprobe.d/vfio.conf
fi

echo "### Configuring boot image..."
MODULES=(efivarfs)
[[ "${VFIO_IDS}" != "" ]] && MODULES+=(vfio_pci vfio vfio_iommu_type1 vfio_virqfd)
[[ "${HAS_NVIDIA}" == "1" ]] && MODULES+=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
sed -i "s|MODULES=(\(.*\))|MODULES=(${MODULES[*]})|g" /etc/mkinitcpio.conf
#original: HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)
HOOKS=(base udev autodetect modconf block encrypt openswap)
[[ "${ALLOW_SUSPEND}" == "1" ]] && HOOKS+=(resume)
HOOKS+=(zfs filesystems keyboard)
sed -i "s|HOOKS=(\(.*\))|HOOKS=(${HOOKS[*]})|g" /etc/mkinitcpio.conf
#echo 'COMPRESSION="cat"' >>/etc/mkinitcpio.conf
mkinitcpio -P

echo "### Installing bootloader..."
bootctl --path=/boot install
KERNEL_PARAMS="initrd=/intel-ucode.img initrd=/initramfs-${KERNEL}.img loglevel=3 zfs=z/root rw"
[[ "${VFIO_IDS}" != "" ]] && KERNEL_PARAMS="${KERNEL_PARAMS} intel_iommu=on iommu=pt"
[[ "${HAS_NVIDIA}" == "1" ]] && KERNEL_PARAMS="${KERNEL_PARAMS} nvidia-drm.modeset=1"
[[ "${ALLOW_SUSPEND}" == "1" ]] && KERNEL_PARAMS="${KERNEL_PARAMS} resume=/dev/mapper/swap0"
mkdir -p /boot/loader
echo "default arch" >/boot/loader/loader.conf
mkdir -p /boot/loader/entries
cat << EOF >>/boot/loader/entries/arch.conf
title   Arch Linux
efi     /vmlinuz-${KERNEL}
options ${KERNEL_PARAMS}
EOF

echo "### Configuring nVidia updates..."
#/etc/pacman.d/hooks/nvidia.hook

echo "### Configuring Zsh..."
chsh -s /bin/zsh

echo "### Preparing post-boot install..."
#/etc/systemd/system/getty@tty1.service.d/override.conf
#/root/.zlogin
#/root/.runonce.sh
chmod a+x ~/.runonce.sh
