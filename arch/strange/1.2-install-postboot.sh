#!/bin/bash
set -e

# TODO
# vnc?
# https://wiki.archlinux.org/index.php/Fan_speed_control#Fancontrol_(lm-sensors)

OTHER_USERS=()
PACKAGES=(
    # Misc
    ccache rsync p7zip tmux
    clang llvm lldb gcc gdb cmake ninja
    # UPS
    apcupsd
    # Sensors
    lm_sensors nvme-cli
    # Xorg
    xorg
    # KDE
    plasma-meta kde-applications-meta xdg-user-dirs sddm sddm-kcm
    # # Fonts
    # adobe-source-code-pro-fonts 
    # adobe-source-sans-pro-fonts 
    # font-bh-ttf
    # gnu-free-fonts 
    # noto-fonts 
    # ttf-anonymous-pro 
    # ttf-bitstream-vera 
    # ttf-croscore 
    # ttf-dejavu 
    # ttf-droid 
    # ttf-fantasque-sans-mono 
    # ttf-fira-code 
    # ttf-fira-mono 
    # ttf-gentium
    # ttf-hack 
    # ttf-inconsolata 
    # ttf-liberation 
    # ttf-linux-libertine 
    # ttf-roboto 
    # ttf-ubuntu-font-family
    # Color
    displaycal colord colord-kde
    # Printing
    cups cups-pdf ghostscript gsfonts
    # # Wine
    # wine wine_gecko wine-mono winetricks
    # # Applications
    # copyq
    # libreoffice-still hunspell hunspell-en_US libmythes mythes-en
    # scribus
    # gimp
    # vlc
    # mkvtoolnix-cli mkvtoolnix-gui
    # youtube-dl
    # speedtest-cli
    # # Steam
    # steam steam-native-runtime ttf-liberation
    # # Games
    # dosbox
    # scummvm
    # retroarch
    # dolphin-emu
    # KVM
    qemu-headless qemu-arch-extra libvirt ebtables dnsmasq bridge-utils openbsd-netcat virt-manager ovmf
)
AUR_PACKAGES=(
    zfs-auto-snapshot
    hfsprogs
    docker nvidia-container-toolkit
    google-chrome
    visual-studio-code-bin
    # makemkv
    # clion clion-gdb clion-jre clion-lldb
    # android-studio 
    # gitahead guitar
    # bcompare bcompare-kde5
    # slack-desktop
    # zoom
    # #minecraft-launcher
    # #ffmpeg-full
)
SEAT1_DEVICES=(
    /sys/devices/pci0000:00/0000:00:1c.6/0000:05:00.0/0000:06:00.0/drm/card0
    /sys/devices/pci0000:00/0000:00:1c.6/0000:05:00.0/0000:06:00.0/graphics/fb0
    /sys/devices/pci0000:00/0000:00:14.0/usb1
    /sys/devices/pci0000:00/0000:00:1f.3/sound/card0
    /sys/devices/platform/pcspkr/input/input29
)
VFIO_IDS="1002:67ff,1002:aae0,10de:1b06,10de:10ef"


echo "### Post-boot ZFS config..."
zfs load-key -a
zpool set cachefile=/etc/zfs/zpool.cache boot
zpool set cachefile=/etc/zfs/zpool.cache z
if [[ -d /bulk ]]
then
    zpool set cachefile=/etc/zfs/zpool.cache bulk
fi
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
if [[ -d /bulk ]]
then
    systemctl enable zfs-scrub@bulk.timer
fi

zgenhostid $(hostid)

zfs create -o mountpoint=/home z/home
zfs create -o mountpoint=/var/lib/docker z/docker
zfs create -o mountpoint=/var/lib/libvirt/images z/images
zfs create z/images/scratch

mkinitcpio -p linux-zen

echo "### Installing Packages..."
sed -i 's/#Color/Color/g' /etc/pacman.conf
pacman -S --needed --noconfirm "${PACKAGES[@]}"

echo "### Adding users..."
#/etc/sudoers.d/wheel
#/etc/sudoers.d/builder

useradd -D --shell /bin/zsh

useradd --user-group --create-home --system gustafson
if [[ -d /bulk ]]
then
    chown -R gustafson:gustafson /bulk
    chmod 775 /bulk
    chmod g+s /bulk
    setfacl -d -m group:gustafson:rwx /bulk
fi

for U in Josh "${OTHER_USERS[@]}"
do
    u=$(echo "${U}" | awk '{print tolower($0)}')
    useradd --groups gustafson --user-group --create-home "${u}"
    cat <<EOF | passwd "${u}"
changeme
changeme
EOF
    passwd -e "${u}"
    mkdir -p /home/${u}/Pictures
    if [[ -d /bulk ]]
    then
        ln -s /bulk/Photos/Favorites /home/${u}/Pictures/Favorites
    fi
    ln -s /beast/Published/Photos /home/${u}/Pictures/Family
    chown -R ${u}:${u} /home/${u}
done
for U in "${OTHER_USERS[@]}"
do
    u=$(echo "${U}" | awk '{print tolower($0)}')
    if [[ -d /bulk ]]
    then
        chown -R ${u}:${u} /bulk/Kids/${U}
        ln -s /bulk/Kids/${U} /home/${u}/Documents
    fi
    chown -R ${u}:${u} /home/${u}
done

usermod -a -G wheel josh
mkdir -p /home/josh/.ssh
curl https://github.com/jgus.keys >> /home/josh/.ssh/authorized_keys
chmod 400 /home/josh/.ssh/authorized_keys
chown -R josh:josh /home/josh/.ssh

echo "### Configuring makepkg..."
sed -i 's/!ccache/ccache/g' /etc/makepkg.conf
cat <<EOF >>/etc/makepkg.conf 
MAKEFLAGS="-j$(nproc)"
BUILDDIR=/tmp/makepkg
EOF

echo "### Configuring UPS..."
systemctl enable apcupsd.service

echo "### Configuring Sensors..."
sensors-detect --auto

echo "### Configuring Xorg..."
cp -r /usr/share/X11/xorg.conf.d /etc/X11/
for d in "${SEAT1_DEVICES[@]}"
do
    loginctl attach seat1 "${d}"
done

# echo "### Fetching MS Fonts..."
# cd /tmp
# 7z e "/beast/Software/MSDN/Windows/Windows 10/Win10_1809Oct_English_x64.iso" sources/install.wim
# 7z e install.wim 1/Windows/{Fonts/"*".{ttf,ttc},System32/Licenses/neutral/"*"/"*"/license.rtf} -y -o/usr/share/fonts/WindowsFonts
# chmod 755 /usr/share/fonts/WindowsFonts

echo "### Configuring KDE..."
systemctl enable sddm.service

echo "### Configuring Printing..."
systemctl enable org.cups.cupsd.service

echo "### Configuring Steam..."
if [[ -d /bulk ]]
then
    mkdir /bulk/steam
    chown gustafson:gustafson /bulk/steam
fi

echo "### Configuring KVM..."
# TODO - check kernel modules? https://wiki.archlinux.org/index.php/KVM#Kernel_support
systemctl enable --now libvirtd.service
systemctl enable libvirtd-snapshot.service
virsh net-define "$(cd "$(dirname "$0")" ; pwd)/libvirt/internal-network.xml"
virsh net-autostart internal
virsh net-start internal
echo "options vfio_pci ids=${VFIO_IDS}" >> /etc/modprobe.d/vfio_pci.conf
cat << EOF >> /etc/libvirt/qemu.conf
nvram = [
	"/usr/share/ovmf/x64/OVMF_CODE.fd:/usr/share/ovmf/x64/OVMF_VARS.fd"
]
EOF
# TODO - hook for images on startup/shutdown?

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
alias yayinst='sudo -u builder yay -Syu --needed'
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
for pool in boot z/root z/home z/docker z/images
do
    zfs snapshot ${pool}@post-boot-install
done

echo "### Installing AUR Packages (interactive)..."
sudo -u builder yay -S --needed "${AUR_PACKAGES[@]}"

echo "### Configuring ZFS Snapshots..."
# /etc/systemd/system/zfs-auto-snapshot-*.service.d
zfs set com.sun:auto-snapshot=true boot
zfs set com.sun:auto-snapshot=true z
zfs set com.sun:auto-snapshot=false z/root/var
zfs set com.sun:auto-snapshot=false z/images/scratch
for i in monthly weekly daily hourly frequent
do
    systemctl enable zfs-auto-snapshot-${i}.timer
done

echo "### Configuring Docker..."
#/etc/docker/daemon.json
systemctl enable --now docker.service
systemctl enable docker-snapshot.service
docker volume create portainer_data
docker run --name portainer -d --restart always -p 8000:8000 -p 9000:9000 -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer

echo "### Making a snapshot..."
for pool in boot z/root z/home z/docker z/images
do
    zfs snapshot ${pool}@aur-pacakges-installed
done

echo "### Done with post-boot install! Rebooting..."
reboot
