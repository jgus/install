#!/bin/bash
set -e

echo "### Post-boot ZFS config..."
zfs load-key -a
zpool set cachefile=/etc/zfs/zpool.cache boot
zpool set cachefile=/etc/zfs/zpool.cache z
zfs mount -a

#/etc/systemd/system/zfs-load-key.service
#/etc/systemd/system/zfs-scrub@.timer
#/etc/systemd/system/zfs-scrub@.service

systemctl enable zfs.target
systemctl enable zfs-import-cache
systemctl enable zfs-mount
systemctl enable zfs-import.target
systemctl enable zfs-load-key.service
systemctl enable zfs-scrub@boot.timer
systemctl enable zfs-scrub@z.timer

zgenhostid $(hostid)

zfs create -o mountpoint=/home z/home
zfs create -o mountpoint=/var/lib/docker z/docker

mkinitcpio -p linux-zen

echo "### Installing Packages..."
sed -i 's/#Color/Color/g' /etc/pacman.conf
PACKAGES=(
    # Xorg
    xorg
    # KDE
    plasma-meta kde-applications-meta xdg-user-dirs sddm sddm-kcm
    # Applications
    vlc
    # Misc
    ccache
)
pacman -S --needed --noconfirm "${PACKAGES[@]}"

echo "### Configuring makepkg..."
sed -i 's/!ccache/ccache/g' /etc/makepkg.conf
cat <<EOF >>/etc/makepkg.conf 
MAKEFLAGS="-j$(nproc)"
BUILDDIR=/tmp/makepkg
EOF

echo "### Configuring Xorg..."
#cp /usr/share/X11/xorg.conf.d/* /etc/X11/xorg.conf.d/
#nvidia-xconfig
#/etc/X11/xorg.conf

echo "### Configuring KDE..."
systemctl enable sddm.service

echo "### Adding users..."
#/etc/sudoers.d/wheel
#/etc/sudoers.d/builder
useradd -D --shell /bin/zsh
useradd --user-group --create-home --system gustafson
for u in josh kayleigh john william lyra
do
    useradd --groups gustafson --user-group --create-home "${u}"
    cat <<EOF | passwd "${u}"
changeme
changeme
EOF
    passwd -e "${u}"
done
usermod -a -G wheel josh

mkdir -p /home/josh/.ssh
curl https://github.com/jgus.keys >> /home/josh/.ssh/authorized_keys
chmod 400 /home/josh/.ssh/authorized_keys
chown -R josh:josh /home/josh/.ssh

useradd --user-group --home-dir /var/cache/builder --create-home --system builder
chmod ug+ws /var/cache/builder
setfacl -m u::rwx,g::rwx /var/cache/builder

echo "### Installing Yay..."
cd /var/cache/builder
sudo -u builder git clone https://aur.archlinux.org/yay.git
cd yay
sudo -u builder makepkg -si --needed --noconfirm

cat <<EOF
#####
#
# Please enter a root password:
#
#####
EOF
passwd

echo "### Cleaning up..."
rm -rf /install
rm /etc/systemd/system/getty@tty1.service.d/override.conf

echo "### Making a snapshot..."
for pool in boot z/root z/home z/docker
do
    zfs snapshot ${pool}@post-boot-install
done

echo "### Installing AUR Packages (interactive)..."
AUR_PACKAGES=(
    google-chrome
    #ffmpeg-full
)
sudo -u builder yay -S --needed "${AUR_PACKAGES[@]}"
for pool in boot z/root z/home z/docker
do
    zfs snapshot ${pool}@aur-pacakges-installed
done

echo "### Done with post-boot install! Rebooting..."
reboot
