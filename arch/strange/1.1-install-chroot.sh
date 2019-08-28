#!/bin/sh
set -e

TIME_ZONE=America/Denver
HOSTNAME=strange
PACKAGES=(
    # Kernel
    linux-zen-headers dkms base-devel
    # Drivers
    nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings
    # Bootloader
    intel-ucode grub efibootmgr
    # ZFS
    zfs-dkms
    # General
    git zsh
    # RNG
    rng-tools
    # OpenSSH
    openssh
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

echo "### Configuring network..."
systemctl disable dhcpcd.service
#/etc/netctl/bridge
netctl enable bridge

echo "### Installing pacakages..."
cat <<EOF >>/etc/pacman.conf

[multilib]
Include = /etc/pacman.d/mirrorlist

[archzfs]
Server = https://archzfs.com/\$repo/\$arch
EOF
pacman-key -r F75D9D76
pacman-key --lsign-key F75D9D76
# remove default kernel (we don't want to bother building modules for it)
pacman -Rs --noconfirm linux
pacman -Syyu --needed --noconfirm "${PACKAGES[@]}"

echo "### Configuring boot image..."
# Initramfs
sed -i 's/MODULES=(\(.*\))/MODULES=(\1 efivarfs vfio_pci vfio vfio_iommu_type1 vfio_virqfd nvidia nvidia_modeset nvidia_uvm nvidia_drm)/g' /etc/mkinitcpio.conf
#original: HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)
sed -i 's/HOOKS=(\(.*\))/HOOKS=(base udev autodetect modconf block zfs filesystems keyboard)/g' /etc/mkinitcpio.conf
#echo 'COMPRESSION="cat"' >>/etc/mkinitcpio.conf
mkinitcpio -p linux-zen

echo "### Installing bootloader..."
pushd /efi
for i in *
do
    ZPOOL_VDEV_NAME_PATH=1 grub-install --target=x86_64-efi --efi-directory="/efi/${i}" --bootloader-id="GRUB-${i}"
done
popd
sed -i 's|GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"|GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 nvidia-drm.modeset=1 zfs=z/root intel_iommu=on iommu=pt"|g' /etc/default/grub
#echo "GRUB_GFXPAYLOAD_LINUX=3840x1600x32" >>/etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

echo "### Configuring nVidia updates..."
#/etc/pacman.d/hooks/nvidia.hook

echo "### Configuring Zsh..."
chsh -s /bin/zsh

echo "### Configuring RNG..."
systemctl enable rngd.service

echo "### Configuring SSH..."
cat << EOF >>/etc/ssh/sshd_config
PasswordAuthentication no
AllowAgentForwarding yes
AllowTcpForwarding yes
EOF
systemctl enable sshd.socket
mkdir -p /root/.ssh
curl https://github.com/jgus.keys >> /root/.ssh/authorized_keys
chmod 400 /root/.ssh/authorized_keys

echo "### Preparing post-boot install..."
#/etc/systemd/system/getty@tty1.service.d/override.conf
#/root/.zlogin
#/root/.runonce.sh
chmod a+x ~/.runonce.sh
