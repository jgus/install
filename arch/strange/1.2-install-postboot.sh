#!/bin/bash
set -e

# TODO
# vnc?
# https://wiki.archlinux.org/index.php/Fan_speed_control#Fancontrol_(lm-sensors)

OTHER_USERS=()
PACKAGES=(
    # Misc
    ccache rsync p7zip tmux git-lfs
    clang llvm lldb gcc gdb cmake ninja
    opencl-nvidia ocl-icd cuda clinfo
    xmlstarlet
    # Filesystems
    smbnetfs sshfs fuseiso
    # Bluetooth
    bluez bluez-utils
    # UPS
    apcupsd
    # Sensors
    lm_sensors nvme-cli
    # Xorg
    xorg lightdm lightdm-gtk-greeter tigervnc
    piper
    xbanish
    # KDE
    plasma-meta kde-applications-meta xdg-user-dirs
    gdm
    # Fonts
    adobe-source-code-pro-fonts
    adobe-source-sans-pro-fonts
    font-bh-ttf
    gnu-free-fonts
    noto-fonts
    ttf-anonymous-pro
    ttf-bitstream-vera
    ttf-croscore
    ttf-dejavu
    ttf-droid
    ttf-fantasque-sans-mono
    ttf-fira-code
    ttf-fira-mono
    ttf-gentium
    ttf-hack
    ttf-inconsolata
    ttf-joypixels
    ttf-liberation
    ttf-linux-libertine
    ttf-roboto
    ttf-ubuntu-font-family
    # Color
    displaycal colord colord-kde
    # Wine
    wine wine_gecko wine-mono winetricks
    # Applications
    copyq
    firefox
    remmina freerdp
    libreoffice-still hunspell hunspell-en_US libmythes mythes-en
    scribus
    gimp
    vlc
    strawberry gstreamer gst-libav gst-plugins-base gst-plugins-good gst-plugins-ugly
    rhythmbox
    mkvtoolnix-cli mkvtoolnix-gui
    youtube-dl
    speedtest-cli
    darktable hugin perl-image-exiftool
    audacity
    gparted
    # Java
    jdk-openjdk jdk8-openjdk icedtea-web
    # Games
    dosbox
    scummvm
    retroarch
    dolphin-emu
    # KVM
    qemu qemu-arch-extra libvirt ebtables dnsmasq bridge-utils openbsd-netcat virt-manager ovmf
)
AUR_PACKAGES=(
    # ZFS
    zfs-auto-snapshot
    # Filesystems
    hfsprogs
    # # Malware
    # clamav clamav-unofficial-sigs clamtk
    # Printing
    cups cups-pdf ghostscript gsfonts cnrdrvcups-lb
    # Docker
    docker nvidia-container-toolkit
    # Chrome
    google-chrome
    # Office Communication
    slack-desktop zoom
    # Development
    python2 python2-virtualenv
    visual-studio-code-bin
    gitahead qgit giggle gitg gitextensions
    bcompare bcompare-kde5
    clion clion-gdb clion-jre clion-lldb
    #openblas-lapack-openmp
    android-studio
    # MakeMKV
    makemkv ccextractor
    # Steam
    steam steam-native-runtime ttf-liberation steam-fonts
    # Minecraft
    minecraft-launcher
)
SEAT1_DEVICES=(
    /sys/devices/pci0000:00/0000:00:1c.6/0000:05:00.0/0000:06:00.0/drm/card0
    /sys/devices/pci0000:00/0000:00:1c.6/0000:05:00.0/0000:06:00.0/graphics/fb0
    /sys/devices/pci0000:00/0000:00:14.0/usb1
    /sys/devices/pci0000:00/0000:00:1f.3/sound/card0
    /sys/devices/platform/pcspkr/input/input29
    /sys/devices/pci0000:00/0000:00:1c.0/0000:03:00.0/usb3
)


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
    #ln -s /beast/Published/Photos /home/${u}/Pictures/Family
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

zfs create -o canmount=off z/home/josh
for $i in sync steam
do
    zfs create z/home/josh/${i}
    chown josh:josh /home/josh/${i}
done
zfs create -o mountpoint=/git z/git
chown josh:josh /git`

usermod -a -G wheel josh
usermod -a -G libvirt josh
mkdir -p /home/josh/.config/libvirt
echo 'uri_default = "qemu:///system"' >> /home/josh/.config/libvirt/libvirt.conf
chown -R josh:josh /home/josh/.config/libvirt
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

echo "### Configuring Samba..."
# /etc/samba/smb.conf
systemctl enable smb.service
mkdir -p /home/josh/.config/systemd/user
cat << EOF >> /home/josh/.config/systemd/user/smbnetfs.service
[Unit]
Description=smbnetfs

[Service]
ExecStart=/usr/bin/smbnetfs %h/smb
ExecStop=/bin/fusermount -u %h/smb

[Install]
WantedBy=default.target
EOF
chown -R josh:josh /home/josh/.config
sudo -u josh systemctl --user enable smbnetfs

echo "### Configuring Bluetooth..."
cat << EOF >> /etc/bluetooth/main.conf

[Policy]
AutoEnable=true
EOF
systemctl enable bluetooth.service

echo "### Configuring UPS..."
systemctl enable apcupsd.service

echo "### Configuring Sensors..."
sensors-detect --auto

echo "### Configuring Xorg..."
systemctl enable ratbagd.service
for d in "${SEAT1_DEVICES[@]}"
do
    loginctl attach seat1 "${d}"
done
cat << EOF >>/home/josh/.xinitrc
#!/bin/sh
xbanish &
EOF
chown josh:josh /home/josh/.xinitrc
chmod a+x /home/josh/.xinitrc

echo "### Configuring Fonts..."
ln -sf ../conf.avail/75-joypixels.conf /etc/fonts/conf.d/75-joypixels.conf

echo "### Fetching MS Fonts..."
cd /tmp
7z e "/beast/Software/MSDN/Windows/Windows 10/Win10_1809Oct_English_x64.iso" sources/install.wim
7z e install.wim 1/Windows/{Fonts/"*".{ttf,ttc},System32/Licenses/neutral/"*"/"*"/license.rtf} -y -o/usr/share/fonts/WindowsFonts
chmod 755 /usr/share/fonts/WindowsFonts

echo "### Configuring LightDM..."
cat << EOF >>/etc/lightdm/lightdm.conf

### Local Config

[VNCServer]
enabled=true
command=Xvnc -rfbauth /etc/vncpasswd
port=5900
width=1440
height=900
depth=24
EOF
#systemctl enable lightdm.service

echo "### Configuring GNOME..."
systemctl enable gdm.service
systemctl enable xvnc.socket

echo "### Configuring Printing..."
systemctl enable org.cups.cupsd.service

echo "### Configuring Steam..."
if [[ -d /bulk ]]
then
    mkdir /bulk/steam
    chown gustafson:gustafson /bulk/steam
fi

echo "### Configuring KVM..."
systemctl enable --now libvirtd.service
systemctl enable libvirtd-snapshot.service
virsh net-define "$(cd "$(dirname "$0")" ; pwd)/libvirt/internal-network.xml"
virsh net-autostart internal
virsh net-start internal
cat << EOF >> /etc/libvirt/qemu.conf
nvram = [
	"/usr/share/ovmf/x64/OVMF_CODE.fd:/usr/share/ovmf/x64/OVMF_VARS.fd"
]
EOF

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

# echo "### Configuring ZFS Snapshots..."
# # /etc/systemd/system/zfs-auto-snapshot-*.service.d
zfs set com.sun:auto-snapshot=true boot
zfs set com.sun:auto-snapshot=true z
zfs set com.sun:auto-snapshot=false z/root/var
zfs set com.sun:auto-snapshot=false z/images/scratch
for i in monthly weekly daily hourly frequent
do
    systemctl enable zfs-auto-snapshot-${i}.timer
done

# echo "### Configuring ClamAV..."
# sed -i 's/^User/#User/g' /etc/pacman.conf
# cat << EOF >> /etc/clamav/clamd.conf

# ### Local Settings
# User root
# MaxThreads 16
# MaxDirectoryRecursion 30
# VirusEvent /etc/clamav/detected.sh

# ExcludePath ^/proc/
# ExcludePath ^/sys/
# ExcludePath ^/dev/
# ExcludePath ^/run/
# ExcludePath ^/beast/
# ExcludePath ^/home/josh/smb/

# ScanOnAccess true
# OnAccessMountPath /
# OnAccessExcludePath /proc/
# OnAccessExcludePath /sys/
# OnAccessExcludePath /dev/
# OnAccessExcludePath /run/
# OnAccessExcludePath /var/log/
# OnAccessExcludePath /beast/
# OnAccessExcludePath /home/josh/smb/
# OnAccessExtraScanning true
# OnAccessExcludeRootUID yes

# EOF
# freshclam
# clamav-unofficial-sigs.sh
# systemctl enable clamav-freshclam.service
# systemctl enable clamav-unofficial-sigs.timer
# systemctl enable clamav-daemon.service

echo "### Configuring Docker..."
#/etc/docker/daemon.json
systemctl enable --now docker.service
systemctl enable docker-snapshot.service
docker volume create portainer_data
systemctl enable portainer.service
docker volume create syncthing_config
systemctl enable syncthing.service
usermod -a -G docker josh

echo "### Making a snapshot..."
for pool in boot z/root z/home z/docker z/images
do
    zfs snapshot ${pool}@aur-pacakges-installed
done

echo "### Done with post-boot install! Rebooting..."
reboot
