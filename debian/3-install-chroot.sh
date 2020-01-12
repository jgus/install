#!/bin/bash
set -e

HOSTNAME=$1
source "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/config.env

lscpu | grep GenuineIntel && HAS_INTEL_CPU=1
lscpu | grep AuthenticAMD && HAS_AMD_CPU=1

grep Debian /etc/issue && DISTRO=debian
grep Arch /etc/issue && DISTRO=arch
case "${DISTRO}" in
    arch)
    ;;
    debian)
    ;;
    *)
        echo "!!! Failed to detect distro:"
        cat /etc/issue
        exit 1
    ;;
esac

KERNEL=${KERNEL:-linux}

case "${DISTRO}" in
    arch)
        BOOT_PACKAGES=(
            # Base
            diffutils logrotate man-db man-pages nano netctl usbutils vi which
            # Kernel
            ${KERNEL}-headers linux-firmware dkms base-devel
            # Bootloader
            efibootmgr
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
        [[ "${HAS_INTEL_CPU}" == "1" ]] && BOOT_PACKAGES+=(intel-ucode)
        # TODO AMD
        [[ "${HAS_NVIDIA}" == "1" ]] && BOOT_PACKAGES+=(
            nvidia-dkms
        )
    ;;
    
    debian)
        BOOT_PACKAGES=(
            dpkg-dev linux-headers-amd64 linux-image-amd64
            zfs-initramfs
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
    ;;
    
    *)
        echo "!!! Unknown distro ${DISTRO}"
        exit 1
    ;;
esac

# Password
cat <<EOF | passwd
changeme
changeme
EOF

echo "### Installing pacakages..."
case "${DISTRO}" in
    arch)
        sed -i "s|#Color|Color|g" /etc/pacman.conf
        cat <<EOF >>/etc/pacman.conf

[multilib]
Include = /etc/pacman.d/mirrorlist

[archzfs]
Server = https://archzfs.com/\$repo/\$arch
EOF
        pacman-key -r F75D9D76
        pacman-key --lsign-key F75D9D76
        rsync -arP root@loki:/var/cache/pacman/pkg/ /var/cache/pacman/pkg || true
        pacman -Syyu --needed --noconfirm "${BOOT_PACKAGES[@]}"
    ;;
    
    debian)
        cat << EOF >/etc/apt/sources.list
deb http://deb.debian.org/debian buster main contrib non-free
deb-src http://deb.debian.org/debian buster main contrib non-free
EOF
        cat << EOF >/etc/apt/sources.list.d/buster-backports.list
deb http://deb.debian.org/debian buster-backports main contrib
deb-src http://deb.debian.org/debian buster-backports main contrib
EOF
        cat << EOF >/etc/apt/preferences.d/90_zfs
Package: libnvpair1linux libuutil1linux libzfs2linux libzpool2linux zfs-dkms zfs-initramfs zfs-test zfsutils-linux zfsutils-linux-dev zfs-zed
Pin: release n=buster-backports
Pin-Priority: 990
EOF
        ln -s /proc/self/mounts /etc/mtab
        apt update
        apt install --yes "${BOOT_PACKAGES[@]}"
    ;;
    
    *)
        echo "!!! Unknown distro ${DISTRO}"
        exit 1
    ;;
esac

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

echo "### Root opt install..."
/root/opt/install.sh

echo "### Configuring network..."
case "${DISTRO}" in
    arch)
        systemctl enable NetworkManager.service
    ;;
    
    debian)
        sed -i "s|managed=.*|managed=true|g" /etc/NetworkManager/NetworkManager.conf
    ;;
    
    *)
        echo "!!! Unknown distro ${DISTRO}"
        exit 1
    ;;
esac

echo "### Configuring VFIO..."
if [[ "${VFIO_IDS}" != "" ]]
then
    echo "options vfio_pci ids=${VFIO_IDS}" >> /etc/modprobe.d/vfio.conf
fi

echo "### Configuring boot image..."
case "${DISTRO}" in
    arch)
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
        mkinitcpio -p ${KERNEL}
    ;;
    
    debian)
        # Nothing to do!
    ;;
    
    *)
        echo "!!! Unknown distro ${DISTRO}"
        exit 1
    ;;
esac

echo "### Installing bootloader..."
# /etc/kernel/postinst.d/bootctl
case "${DISTRO}" in
    arch)
        [[ "${HAS_INTEL_CPU}" == "1" ]] && KERNEL_PARAMS="${KERNEL_PARAMS} initrd=/intel-ucode.img"
        # TODO AMD
        KERNEL_PARAMS="${KERNEL_PARAMS} initrd=/initramfs-${KERNEL}.img"
    ;;
    
    debian)
    ;;
    
    *)
        echo "!!! Unknown distro ${DISTRO}"
        exit 1
    ;;
esac
KERNEL_PARAMS="${KERNEL_PARAMS} loglevel=3 zfs=z/${DISTRO} rw"
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
case "${DISTRO}" in
    arch)
        echo "default arch" >/boot/loader/loader.conf
        cat << EOF >>/boot/loader/entries/arch.conf
title   Arch Linux
efi     /vmlinuz-${KERNEL}
options ${KERNEL_PARAMS}
EOF
    ;;
    
    debian)
        echo "default debian" >/boot/loader/loader.conf
        sed -i "s|^options*$|options ${KERNEL_PARAMS}|g" /boot/loader/entries/debian.conf
    ;;
    
    *)
        echo "!!! Unknown distro ${DISTRO}"
        exit 1
    ;;
esac

echo "### Configuring nVidia updates..."
#/etc/pacman.d/hooks/nvidia.hook

echo "### Configuring Zsh..."
chsh -s /bin/zsh

echo "### Preparing post-boot install..."
#/etc/systemd/system/getty@tty1.service.d/override.conf
#/root/.zlogin
#/root/.runonce.sh
chmod a+x ~/.runonce.sh
