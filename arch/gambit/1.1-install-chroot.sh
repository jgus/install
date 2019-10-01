#!/bin/sh
set -e

TIME_ZONE=America/Denver
HOSTNAME=gambit
PACKAGES=(
    # Bootloader
    intel-ucode grub efibootmgr
    # ZFS
    zfs
    # General
    git zsh grml-zsh-config
    # RNG
    rng-tools
    # OpenSSH
    openssh
    # Samba
    samba
)
BEAST_SHARES=(
    #Backup
    #Brown
    #Comics
    #Local Backup
    #Media
    #Media-Storage
    #Minecraft
    #Music
    #Peer
    #Photos
    #Photos-Incoming
    #Private
    #Proxmox-Images
    #Published
    Software
    #Storage
    Temp
    #Tools
    #Users
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
#/etc/systemd/network/
systemctl enable systemd-networkd.service
systemctl enable dhcpcd@br0.service

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

echo "### Configuring boot image..."
# Initramfs
sed -i 's/MODULES=(\(.*\))/MODULES=(\1 efivarfs)/g' /etc/mkinitcpio.conf
#original: HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)
sed -i 's/HOOKS=(\(.*\))/HOOKS=(base udev autodetect modconf block zfs filesystems keyboard)/g' /etc/mkinitcpio.conf
#echo 'COMPRESSION="cat"' >>/etc/mkinitcpio.conf
mkinitcpio -p linux

echo "### Installing bootloader..."
pushd /efi
export ZPOOL_VDEV_NAME_PATH=1
for i in *
do
    grub-install --target=x86_64-efi --efi-directory="/efi/${i}" --bootloader-id="GRUB-${i}"
done
popd
sed -i 's|GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"|GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 zfs=z/root"|g' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

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