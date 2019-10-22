#!/bin/sh
set -e

HOSTNAME=$1
source "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/config.env

BOOT_MODE=${BOOT_MODE:-efi}
KERNEL=${KERNEL:-linux}

PACKAGES+=(
    # Base
    diffutils logrotate man-db man-pages nano netctl usbutils vi which
    # Kernel
    linux-zen-headers linux-firmware dkms base-devel
    # Bootloader
    grub intel-ucode efibootmgr
    # ZFS
    zfs-dkms
    # Sensors
    lm_sensors nvme-cli
    # General
    git git-lfs zsh grml-zsh-config
    diffutils inetutils less logrotate man-db man-pages nano usbutils which
    # RNG
    rng-tools
    # OpenSSH
    openssh
    # Samba
    samba
    # Misc
    ccache rsync p7zip tmux
    )
[[ "${HAS_NVIDIA}" == "1" ]] && PACKAGES+=(
    # Drivers
    nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings
    opencl-nvidia ocl-icd cuda clinfo
     )
[[ "${HAS_BLUETOOTH}" == "1" ]] && PACKAGES+=(
    # Bluetooth
    bluez bluez-utils bluez-plugins
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
systemctl enable NetworkManager.service

echo "### Installing pacakages..."
cat <<EOF >>/etc/pacman.conf

[multilib]
Include = /etc/pacman.d/mirrorlist

[archzfs]
Server = https://archzfs.com/\$repo/\$arch
EOF
pacman-key -r F75D9D76
pacman-key --lsign-key F75D9D76
pacman -Syyu --needed --noconfirm "${PACKAGES[@]}"

echo "### Configuring VFIO..."
if [[ "${VFIO_IDS}" != "" ]]
then
    echo "options vfio_pci ids=${VFIO_IDS}" >> /etc/modprobe.d/vfio.conf
fi

echo "### Configuring power..."
# common/files/etc/skel/.config/powermanagementprofilesrc
[[ "${ALLOW_POWEROFF}" == "1" ]] || cat << EOF >>/etc/polkit-1/rules.d/10-disable-shutdown.rules
polkit.addRule(function(action, subject) {
    if (action.id == "org.freedesktop.login1.reboot" ||
        action.id == "org.freedesktop.login1.reboot-multiple-sessions" ||
        action.id == "org.freedesktop.login1.power-off" ||
        action.id == "org.freedesktop.login1.power-off-multiple-sessions")
    {
        if (subject.isInGroup("wheel")) {
            return polkit.Result.YES;
        } else {
            return polkit.Result.NO;
        }
    }
});
EOF
[[ "${ALLOW_SUSPEND}" == "1" ]] || cat << EOF >>/etc/polkit-1/rules.d/10-disable-suspend.rules
polkit.addRule(function(action, subject) {
    if (action.id == "org.freedesktop.login1.suspend" ||
        action.id == "org.freedesktop.login1.suspend-multiple-sessions" ||
        action.id == "org.freedesktop.login1.hibernate" ||
        action.id == "org.freedesktop.login1.hibernate-multiple-sessions")
    {
        return polkit.Result.NO;
    }
});
EOF

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
systemctl enable sshd.service
mkdir -p /root/.ssh
curl https://github.com/jgus.keys >> /root/.ssh/authorized_keys
chmod 400 /root/.ssh/authorized_keys

echo "### Configuring Samba..."
mkdir /beast
cat <<EOF >>/etc/fstab

# Beast
EOF
for share in "${BEAST_SHARES[@]}"
do
    mkdir /beast/${share}
    echo "//beast/${share} /beast/${share} cifs noauto,nofail,x-systemd.automount,x-systemd.requires=network-online.target,x-systemd.device-timeout=30,credentials=/etc/samba/private/beast 0 0" >>/etc/fstab
done

echo "### Preparing post-boot install..."
#/etc/systemd/system/getty@tty1.service.d/override.conf
#/root/.zlogin
#/root/.runonce.sh
chmod a+x ~/.runonce.sh
