#!/bin/bash -e

HOSTNAME=$(cat /etc/hostname)
source "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/config.env

KERNEL=${KERNEL:-linux}
HAS_CK_KERNEL=0
case ${KERNEL} in
    linux-ck-*) HAS_CK_KERNEL=1 ;;
esac
ZFS_PACAKGE=zfs-dkms
# case ${KERNEL} in
#     linux|linux-lts|linux-hardened|linux-zen) ZFS_PACAKGE=zfs-${KERNEL} ;;
# esac
NVIDIA_PACAKGE=nvidia-dkms
case ${KERNEL} in
    linux) NVIDIA_PACAKGE=nvidia ;;
    linux-lts) NVIDIA_PACAKGE=nvidia-lts ;;
esac

lscpu | grep GenuineIntel && HAS_INTEL_CPU=1
lscpu | grep AuthenticAMD && HAS_AMD_CPU=1
lspci | grep NVIDIA && HAS_NVIDIA=1

BOOT_PACKAGES=(
    # Base
    diffutils logrotate man-db man-pages nano netctl usbutils vi which wget
    # DKMS
    base-devel dkms ${KERNEL}-headers
    # Bootloader
    efibootmgr
    # Firmware
    fwupd
    # ZFS
    ${ZFS_PACAKGE}
    # Network
    openresolv networkmanager dhclient
    # ZSH
    zsh grml-zsh-config
    # LDAP Auth
    openldap nss-pam-ldapd sssd
)
((HAS_INTEL_CPU)) && PACKAGES+=(intel-ucode)
((HAS_AMD_CPU)) && PACKAGES+=(amd-ucode)
((HAS_NVIDIA)) && BOOT_PACKAGES+=(${NVIDIA_PACAKGE})

echo "### Configuring clock..."
ln -sf "/usr/share/zoneinfo/${TIME_ZONE}" /etc/localtime
hwclock --systohc

echo "### Configuring locale..."
echo "en_US.UTF-8 UTF-8" >>/etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >/etc/locale.conf

echo "### Installing packages..."
sed -i "s|#Color|Color|g" /etc/pacman.conf
cat <<EOF >>/etc/pacman.conf

[multilib]
Include = /etc/pacman.d/mirrorlist

[archzfs]
# Origin Server - France
Server = http://archzfs.com/\$repo/\$arch
# Mirror - Germany
Server = http://mirror.sum7.eu/archlinux/archzfs/\$repo/\$arch
# Mirror - Germany
Server = https://mirror.biocrafting.net/archlinux/archzfs/\$repo/\$arch
# Mirror - India
Server = https://mirror.in.themindsmaze.com/archzfs/\$repo/\$arch

EOF
pacman-key --recv-keys F75D9D76 --keyserver hkp://pool.sks-keyservers.net:80
pacman-key --lsign-key F75D9D76

if ((HAS_CK_KERNEL))
then
    cat <<EOF >>/etc/pacman.conf

[repo-ck]
Server = http://repo-ck.com/\$arch
EOF
    pacman-key -r 5EE46C4C
    pacman-key --lsign-key 5EE46C4C
fi

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
((HAS_NVIDIA)) && MODULES+=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
sed -i "s|MODULES=(\(.*\))|MODULES=(${MODULES[*]})|g" /etc/mkinitcpio.conf
#original: HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)
HOOKS=(base udev autodetect modconf block encrypt openswap)
((ALLOW_SUSPEND)) && HOOKS+=(resume)
HOOKS+=(zfs filesystems keyboard)
sed -i "s|HOOKS=(\(.*\))|HOOKS=(${HOOKS[*]})|g" /etc/mkinitcpio.conf
#echo 'COMPRESSION="cat"' >>/etc/mkinitcpio.conf
mkinitcpio -P

echo "### Installing bootloader..."
KERNEL_PARAMS=()
((HAS_INTEL_CPU)) && KERNEL_PARAMS+=(initrd=/intel-ucode.img)
KERNEL_PARAMS+=(initrd=/initramfs-${KERNEL}.img loglevel=3 zfs=z/root rw)
((HAS_INTEL_CPU)) && [[ "${VFIO_IDS}" != "" ]] && KERNEL_PARAMS+=(intel_iommu=on iommu=pt)
((HAS_NVIDIA)) && KERNEL_PARAMS+=(nvidia-drm.modeset=1)
((ALLOW_SUSPEND)) && KERNEL_PARAMS+=(resume=/dev/mapper/swap0)
echo " ${KERNEL_PARAMS[@]}" >>/boot/${KERNEL}-opts.txt
efibootmgr --verbose --disk ${SYSTEM_DEVICES[0]} --part 1  --create --label "Arch Linux (${KERNEL})" --loader /vmlinuz-${KERNEL} --append-binary-args /boot/${KERNEL}-opts.txt
echo "vmlinuz-${KERNEL} ${KERNEL_PARAMS[@]}" >>/boot/${KERNEL}-startup.nsh

# echo "### TEMP!!!"
# zsh

echo "### Configuring nVidia updates..."
mkdir -p /etc/pacman.d/hooks
cat << EOF >>/etc/pacman.d/hooks/nvidia.hook
[Trigger]
Operation=Install
Operation=Upgrade
Operation=Remove
Type=Package
Target=${NVIDIA_PACAKGE}
Target=${KERNEL}

[Action]
Description=Update Nvidia module in initcpio
Depends=mkinitcpio
When=PostTransaction
NeedsTargets
Exec=/bin/sh -c 'while read -r trg; do case $trg in linux) exit 0; esac; done; /usr/bin/mkinitcpio -P'
EOF

echo "### Configuring Zsh..."
chsh -s /bin/zsh

echo "### Preparing post-boot install..."
#/etc/systemd/system/getty@tty1.service.d/override.conf
#/root/.zlogin
#/root/.runonce.sh
chmod a+x ~/.runonce.sh
