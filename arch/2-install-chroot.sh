#!/bin/sh
set -e

HOSTNAME=$1
source "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/config.env

BOOT_MODE=${BOOT_MODE:-efi}
KERNEL=${KERNEL:-linux}

BOOT_PACKAGES=(
    # Base
    diffutils logrotate man-db man-pages nano netctl usbutils vi which
    # Kernel
    ${KERNEL}-headers linux-firmware dkms base-devel
    # Bootloader
    grub intel-ucode efibootmgr
    # ZFS
    zfs-dkms
    # Network
    openresolv networkmanager dhclient
    )
[[ "${HAS_NVIDIA}" == "1" ]] && BOOT_PACKAGES+=(
    # Drivers
    nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings
    opencl-nvidia ocl-icd cuda clinfo
     )

# Password
cat <<EOF | passwd
changeme
changeme
EOF

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
cat <<EOF >>/etc/pacman.conf

[multilib]
Include = /etc/pacman.d/mirrorlist

[archzfs]
Server = https://archzfs.com/\$repo/\$arch
EOF
pacman-key -r F75D9D76
pacman-key --lsign-key F75D9D76
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
mkinitcpio -p ${KERNEL}

echo "### Installing bootloader..."
export ZPOOL_VDEV_NAME_PATH=1
if [[ "${BOOT_MODE}" == "bios" ]]
then
    grub-install --target=i386-pc "${SYSTEM_DEVICES[0]}"
else
    grub-install --target=x86_64-efi --efi-directory="/boot" --bootloader-id="GRUB"
fi
KERNEL_PARAMS="loglevel=3 zfs=z/root"
[[ "${VFIO_IDS}" != "" ]] && KERNEL_PARAMS="${KERNEL_PARAMS} intel_iommu=on iommu=pt"
[[ "${HAS_NVIDIA}" == "1" ]] && KERNEL_PARAMS="${KERNEL_PARAMS} nvidia-drm.modeset=1"
[[ "${ALLOW_SUSPEND}" == "1" ]] && KERNEL_PARAMS="${KERNEL_PARAMS} resume=/dev/mapper/swap0"
sed -i "s|GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"|GRUB_CMDLINE_LINUX_DEFAULT=\"${KERNEL_PARAMS}\"|g" /etc/default/grub
sed -i "s|GRUB_TIMEOUT=.*|GRUB_TIMEOUT=0|g" /etc/default/grub
cat << EOF >>/etc/default/grub
GRUB_HIDDEN_TIMEOUT=0
GRUB_HIDDEN_TIMEOUT_QUIET=true
EOF
#echo "GRUB_GFXPAYLOAD_LINUX=3840x1600x32" >>/etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

echo "### Configuring nVidia updates..."
#/etc/pacman.d/hooks/nvidia.hook

echo "### Preparing post-boot install..."
#/etc/systemd/system/getty@tty1.service.d/override.conf
#/root/.zlogin
#/root/.runonce.sh
chmod a+x ~/.runonce.sh
