#!/bin/bash -e

HOSTNAME=$(cat /etc/hostname)
source "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/config.env

if [[ "${KERNELS[@]}" == "" ]]
then
    KERNELS=(linux-lts linux)
fi

KERNEL_HEADERS=()
HAS_CK_KERNEL=0
for k in "${KERNELS[@]}"
do
    KERNEL_HEADERS+=(${k}-headers)
    case ${k} in
        linux-ck-*) HAS_CK_KERNEL=1 ;;
    esac
done

lscpu | grep GenuineIntel && HAS_INTEL_CPU=1
lscpu | grep AuthenticAMD && HAS_AMD_CPU=1
lspci | grep NVIDIA && HAS_NVIDIA=1

PACKAGES=(
    # Base
    diffutils logrotate man-db man-pages nano netctl usbutils vi which wget
    # DKMS
    base-devel dkms "${KERNEL_HEADERS[@]}"
    # Bootloader
    efibootmgr
    # Firmware
    fwupd
    # ZFS
    zfs-dkms
    # Network
    openresolv networkmanager dhclient
    # ZSH
    zsh #grml-zsh-config
)
((HAS_INTEL_CPU)) && PACKAGES+=(intel-ucode)
((HAS_AMD_CPU)) && PACKAGES+=(amd-ucode)
((HAS_NVIDIA)) && PACKAGES+=(nvidia-dkms)

echo "### Configuring clock..."
ln -sf "/usr/share/zoneinfo/${TIME_ZONE}" /etc/localtime
hwclock --systohc
systemctl enable systemd-timesyncd.service

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

pacman -Syyu --needed --noconfirm "${PACKAGES[@]}"

echo "### Configuring ZFS..."
systemctl enable zfs.target
systemctl enable zfs-import-cache
systemctl enable zfs-mount
systemctl enable zfs-import.target
#/etc/systemd/system/zfs-scrub@.timer
#/etc/systemd/system/zfs-scrub@.service
systemctl enable zfs-scrub@z.timer
zgenhostid

echo "### Configuring swap..."
systemctl enable swap-ntfs.service

echo "### Configuring network..."
systemctl enable NetworkManager.service

echo "### Configuring Zsh..."
chsh -s /bin/zsh

echo "### Configuring nVidia updates..."
mkdir -p /etc/pacman.d/hooks
cat << EOF >>/etc/pacman.d/hooks/nvidia.hook
[Trigger]
Operation=Install
Operation=Upgrade
Operation=Remove
Type=Package
Target=nvidia-dkms

[Action]
Description=Update Nvidia module in initcpio
Depends=mkinitcpio
When=PostTransaction
Exec=/usr/bin/mkinitcpio -P
EOF

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
HOOKS=(base udev autodetect modconf block encrypt)
((ALLOW_SUSPEND_TO_DISK)) && HOOKS+=(resume)
HOOKS+=(zfs filesystems keyboard)
sed -i "s|HOOKS=(\(.*\))|HOOKS=(${HOOKS[*]})|g" /etc/mkinitcpio.conf
#echo 'COMPRESSION="cat"' >>/etc/mkinitcpio.conf
mkinitcpio -P

echo "### Installing bootloader..."
/usr/local/bin/update-efiboot.sh

# echo "### TEMP!!!"
# zsh

echo "### Preparing post-boot install..."
#/etc/systemd/system/getty@tty1.service.d/override.conf
#/root/.zlogin
#/root/.runonce.sh
chmod a+x ~/.runonce.sh
