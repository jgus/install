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
    # Misc
    ccache rsync
    # Samba
    samba
    # Xorg
    xorg
    # KDE
    plasma-meta kde-applications-meta xdg-user-dirs sddm sddm-kcm
    # Printing
    cups cups-pdf ghostscript gsfonts
    # Wine
    wine wine_gecko wine-mono winetricks
    # Applications
    libreoffice-still hunspell hunspell-en_US hypen hypen-en libmythes mythes-en
    gimp
    vlc
    # Steam
    steam steam-native-runtime ttf-liberation
)
pacman -S --needed --noconfirm "${PACKAGES[@]}"

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

chown -R gustafson:gustafson /bulk
chmod 775 /bulk
chmod g+s /bulk
setfacl -d -m group:gustafson:rwx /bulk

for U in Kayleigh John William Lyra
do
    u=$(echo "${U}" | awk '{print tolower($0)}')
    chown -R ${u}:${u} /bulk/Kids/${U}
    ln -s /bulk/Kids/${U} /home/${u}/Documents
    mkdir -p /home/${u}/Pictures
    ln -s /bulk/Photos/Favorites /home/${u}/Pictures/Favorites
    ln -s /beast/Published/Photos /home/${u}/Pictures/Family
    chown -R ${u}:${u} /home/${u}
done

echo "### Configuring makepkg..."
sed -i 's/!ccache/ccache/g' /etc/makepkg.conf
cat <<EOF >>/etc/makepkg.conf 
MAKEFLAGS="-j$(nproc)"
BUILDDIR=/tmp/makepkg
EOF

echo "### Configuring Samba..."
BEAST_SHARES=(
    #Backup
    Brown
    #Comics
    #Local Backup
    Media
    #Media-Storage
    #Minecraft
    Music
    #Peer
    #Photos
    #Photos-Incoming
    #Private
    #Proxmox-Images
    Published
    Software
    Storage
    Temp
    Tools
    #Users
)
mkdir /beast
cat <<EOF >>/etc/fstab

# Beast
EOF
for share in "${BEAST_SHARES[@]}"
do
    mkdir /beast/${share}
    echo "//beast/${share} /beast/${share} cifs noauto,nofail,x-systemd.automount,x-systemd.requires=network-online.target,x-systemd.device-timeout=30,credentials=/etc/samba/private/beast 0 0" >>/etc/fstab
done


echo "### Configuring Xorg..."
loginctl attach seat1 /sys/devices/pci0000:00/0000:00:03.0/0000:02:00.0/drm/card1
loginctl attach seat1 /sys/devices/pci0000:00/0000:00:03.0/0000:02:00.1/sound/card1
loginctl attach seat1 /sys/devices/pci0000:00/0000:00:1d.0/usb4/4-1/4-1.3/4-1.3:1.1/0003:046D:C534.000B/0003:046D:4023.000C/input/input47
loginctl attach seat1 /sys/devices/pci0000:00/0000:00:1d.0/usb4/4-1/4-1.3/4-1.3:1.1/0003:046D:C534.000B/0003:046D:4054.000D/input/input48
cp -r /usr/share/X11/xorg.conf.d /etc/X11/

echo "### Configuring KDE..."
systemctl enable sddm.service

echo "### Configuring Printing..."
systemctl enable org.cups.cupsd.service

echo "### Configuring Steam..."
mkdir /bulk/steam
chown gustafson:gustafson /bulk/steam

echo "### Installing Yay..."
useradd --user-group --home-dir /var/cache/builder --create-home --system builder
chmod ug+ws /var/cache/builder
setfacl -m u::rwx,g::rwx /var/cache/builder
cd /var/cache/builder
sudo -u builder git clone https://aur.archlinux.org/yay.git
cd yay
sudo -u builder makepkg -si --needed --noconfirm

echo "### Configuring Environment..."
cat <<EOF >>/etc/profile
export EDITOR=nano
alias yay='sudo -u builder yay'
EOF

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
    zfs-snap-manager
    docker nvidia-container-toolkit
    google-chrome
    visual-studio-code-bin
    minecraft-launcher
    #ffmpeg-full
)
sudo -u builder yay -S --needed "${AUR_PACKAGES[@]}"

echo "### Configuring ZFS Snapshots..."
#/etc/zfssnapmanager.cfg
systemctl enable zfs-snap-manager.service

echo "### Configuring Docker..."
#/etc/docker/daemon.json
systemctl enable docker.service
systemctl start docker.service
docker volume create portainer_data
docker run --name portainer -d --restart always -p 8000:8000 -p 9000:9000 -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer

echo "### Making a snapshot..."
for pool in boot z/root z/home z/docker
do
    zfs snapshot ${pool}@aur-pacakges-installed
done

echo "### Done with post-boot install! Rebooting..."
reboot
