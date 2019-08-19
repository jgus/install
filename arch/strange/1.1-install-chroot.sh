#!/bin/sh
set -e

# Password
cat <<EOF | passwd
changeme
changeme
EOF

echo "### Configuring clock..."
ln -sf /usr/share/zoneinfo/America/Denver /etc/localtime
hwclock --systohc

echo "### Configuring locale..."
echo "en_US.UTF-8 UTF-8" >>/etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >/etc/locale.conf

echo "### Configuring hostname..."
HOSTNAME=strange
echo "${HOSTNAME}" >/etc/hostname
cat <<EOF >/etc/hosts
127.0.0.1 localhost
::1 localhost
127.0.1.1 ${HOSTNAME}.localdomain ${HOSTNAME}
EOF

echo "### Configuring network..."
systemctl enable dhcpcd.service

echo "### Installing pacakages..."
cat <<EOF >>/etc/pacman.conf

[multilib]
Include = /etc/pacman.d/mirrorlist

[archzfs]
Server = https://archzfs.com/\$repo/\$arch
EOF
pacman-key -r F75D9D76
pacman-key --lsign-key F75D9D76
PACKAGES=(
    # Kernel
    linux-headers linux-zen linux-zen-headers dkms base-devel
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
pacman -Syyu --needed --noconfirm "${PACKAGES[@]}"

echo "### Configuring boot image..."
# Initramfs
sed -i 's/MODULES=(\(.*\))/MODULES=(\1 ext2 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/g' /etc/mkinitcpio.conf
#sed -i 's|FILES=(\(.*\))|FILES=(\1 /boot/z.key)|g' /etc/mkinitcpio.conf
sed -i 's/HOOKS=(\(.*\)block filesystems keyboard\(.*\))/HOOKS=(\1udev keyboard block zfs filesystems\2)/g' /etc/mkinitcpio.conf
#echo 'COMPRESSION="cat"' >>/etc/mkinitcpio.conf
mkinitcpio -p linux-zen

echo "### Installing bootloader..."
export ZPOOL_VDEV_NAME_PATH=1
for  i in 3 2 1 0
do
    grub-install --target=x86_64-efi --efi-directory="/efi/${i}" --bootloader-id="GRUB-${i}"
done
sed -i 's|GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"|GRUB_CMDLINE_LINUX_DEFAULT="\1 nvidia-drm.modeset=1"|g' /etc/default/grub
#sed -i 's/GRUB_PRELOAD_MODULES="\(.*\)"/GRUB_PRELOAD_MODULES="\1 lvm"/g' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

echo "### Configuring nVidia updates..."
mkdir -p /etc/pacman.d/hooks
cat <<EOF >>/etc/pacman.d/hooks/nvidia.hook
[Trigger]
Operation=Install
Operation=Upgrade
Operation=Remove
Type=Package
Target=nvidia
Target=linux
# Change the linux part above and in the Exec line if a different kernel is used

[Action]
Description=Update Nvidia module in initcpio
Depends=mkinitcpio
When=PostTransaction
NeedsTargets
Exec=/bin/sh -c 'while read -r trg; do case $trg in linux) exit 0; esac; done; /usr/bin/mkinitcpio -P'
EOF

echo "### Configuring Zsh..."
chsh -s /bin/zsh

echo "### Configuring RNG..."
systemctl enable rngd.service

echo "### Configuring SSH..."
echo "PasswordAuthentication no" >>/etc/ssh/sshd_config
systemctl enable sshd.socket
mkdir -p /root/.ssh
curl https://github.com/jgus.keys >> /root/.ssh/authorized_keys
chmod 400 /root/.ssh/authorized_keys

echo "### Preparing post-boot install..."
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat <<EOF >>~/etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin root --noclear %I $TERM
EOF

cat <<EOF >>~/.zlogin
if [[ -x ~/.runonce.sh ]]
then
    rm -f ~/.running.sh
    mv ~/.runonce.sh ~/.running.sh
    ~/.running.sh
    rm -f ~/.running.sh
fi
EOF

cat <<EOF >>~/.runonce.sh
#!/bin/bash
set -e
/install/1.2-install-postboot.sh
EOF
chmod a+x ~/.runonce.sh

# TODO
# ZFS snapshots/replication
# add users (with shell)
# Sync
# Steam
# Wine?
# Multiseat
