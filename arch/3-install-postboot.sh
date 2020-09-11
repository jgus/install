#!/bin/bash -e

echo "### TEMP!!!"
zsh


# TODO
# vnc?
# https://wiki.archlinux.org/index.php/Fan_speed_control#Fancontrol_(lm-sensors)

HOSTNAME=$(hostname)
source "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/config.env
KERNEL=${KERNEL:-linux}

PACKAGES+=(
    # Pacman
    pacman-contrib reflector
    # Sensors
    lm_sensors nvme-cli
    # General
    git git-lfs
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
[[ "${HAS_BLUETOOTH}" == "1" ]] && PACKAGES+=(
    # Bluetooth
    bluez bluez-utils bluez-plugins
    )
[[ "${HAS_GUI}" == "1" ]] && PACKAGES+=(
    # Xorg
    xorg tigervnc
    # KDE
    plasma-meta kde-applications-meta xdg-user-dirs
    qt5-imageformats
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
    gentium-plus-font
    ttf-hack
    ttf-inconsolata
    ttf-joypixels
    ttf-liberation
    ttf-linux-libertine
    ttf-roboto
    ttf-ubuntu-font-family
    # Applications
    code
    freerdp
    libreoffice-still hunspell hunspell-en_US libmythes mythes-en
    scribus
    gimp
    vlc
    )
[[ "${USE_DM}" == "sddm" ]] && PACKAGES+=(
    sddm sddm-kcm
    )
[[ "${USE_DM}" == "gdm" ]] && PACKAGES+=(
    gdm
    )
[[ "${HAS_NVIDIA}" == "1" ]] && PACKAGES+=(
    nvidia-utils lib32-nvidia-utils nvidia-settings
    opencl-nvidia ocl-icd cuda clinfo
    )
[[ "${HAS_DOCKER}" == "1" ]] && PACKAGES+=(
    docker
    )

AUR_PACKAGES+=(
    # Bootloader
    systemd-boot-pacman-hook
    # ZFS
    zfs-auto-snapshot
    )
[[ "${HAS_GUI}" == "1" ]] && AUR_PACKAGES+=(
    # Xorg
    xbanish
    # Printing
    cups cups-pdf ghostscript gsfonts cnrdrvcups-lb
    # Chrome
    google-chrome
    # Steam
    steam steam-native-runtime ttf-liberation steam-fonts
    # Minecraft
    minecraft-launcher
    )
[[ "${HAS_OPTIMUS}" == "1" ]] && AUR_PACKAGES+=(
    optimus-manager optimus-manager-qt
    )
[[ "${HAS_DOCKER}" == "1" ]] && [[ "${HAS_NVIDIA}" == "1" ]] && AUR_PACKAGES+=(
    nvidia-container-toolkit
    )

echo "### Post-boot ZFS config..."
zfs load-key -a
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
systemctl enable zfs-scrub@z.timer
if [[ -d /bulk ]]
then
    systemctl enable zfs-scrub@bulk.timer
fi

zgenhostid $(hostid)

mkinitcpio -P

echo "### Installing packages..."
pacman -Syyu --needed --noconfirm "${PACKAGES[@]}"
systemctl enable reflector.timer

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

echo "### Configuring network..."
if [[ "${HAS_WIFI}" == "1" ]]
then
    for i in /etc/NetworkManager/wifi
    do
        source "${i}"
        nmcli device wifi connect ${ssid} password ${psk}
    done
fi

echo "### Configuring LDAP auth..."
cat << EOF >> /etc/openldap/ldap.conf
BASE        dc=gustafson,dc=me
URI         ldap://ldap.gustafson.me
TLS_REQCERT allow
EOF
sed -i "s|passwd: files|passwd: files sss|g" /etc/nsswitch.conf
sed -i "s|group: files|group: files sss|g" /etc/nsswitch.conf
sed -i "s|shadow: files|shadow: files sss|g" /etc/nsswitch.conf
sed -i "s|netgroup: files|netgroup: files sss|g" /etc/nsswitch.conf
echo "sudoers: files sss" >>/etc/nsswitch.conf
sed -i "s|^uri.*|uri ldap://ldap.gustafson.me/|g" /etc/nslcd.conf
sed -i "s|dc=example,dc=com|dc=gustafson,dc=me|g" /etc/nslcd.conf
cat << EOF >>/etc/nslcd.conf
binddn cn=readonly,dc=gustafson,dc=me
bindpw readonly
EOF
chmod go-rw /etc/nslcd.conf
sed -i "s|enable-cache\(\s*\)passwd\(\s*\)yes|enable-cache\1passwd\2no|g" /etc/nscd.conf
sed -i "s|enable-cache\(\s*\)group\(\s*\)yes|enable-cache\1group\2no|g" /etc/nscd.conf
sed -i "s|enable-cache\(\s*\)netgroup\(\s*\)yes|enable-cache\1netgroup\2no|g" /etc/nscd.conf
source /etc/openldap.env
echo "ldap_default_authtok = ${LDAP_ADMIN_PASSWORD}" >> /etc/sssd/sssd.conf
chmod 600 /etc/sssd/sssd.conf
systemctl enable --now nslcd.service
systemctl enable --now sssd.service

echo "### Configuring RNG..."
systemctl enable rngd.service

echo "### Configuring SSH..."
cat << EOF >>/etc/ssh/sshd_config
PasswordAuthentication no
AllowAgentForwarding yes
AllowTcpForwarding yes
EOF
systemctl enable sshd.service

echo "### Configuring Samba..."
mkdir /beast
cat <<EOF >>/etc/fstab

# Beast
EOF
for share in "${BEAST_SHARES[@]}"
do
    mkdir /beast/${share}
    echo "//beast/${share} /beast/${share} cifs noauto,nofail,x-systemd.automount,x-systemd.requires=network-online.target,x-systemd.device-timeout=30,credentials=/etc/samba/private/beast 0 0" >>/etc/fstab
    mount /beast/${share}
done

echo "### Adding system users..."
#/etc/sudoers.d/wheel
#/etc/sudoers.d/builder

useradd -D --shell /bin/zsh

if [[ -d /bulk ]]
then
    chown -R gustafson:gustafson /bulk
    chmod 775 /bulk
    chmod g+s /bulk
    setfacl -d -m group:gustafson:rwx /bulk
fi

usermod -a -G wheel josh
/etc/mkhome.sh josh

zfs create -o mountpoint=/git z/git
chown josh:josh /git

if which virsh
then
    usermod -a -G libvirt josh
    mkdir -p /home/josh/.config/libvirt
    echo 'uri_default = "qemu:///system"' >> /home/josh/.config/libvirt/libvirt.conf
    chown -R josh:josh /home/josh/.config/libvirt
fi
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
# /etc/systemd/user/smbnetfs.service
[[ -f /etc/samba/smb.conf ]] && systemctl enable smb.service
if which smbnetfs
then
    mkdir -p /home/josh/smb
    chown -R josh:josh /home/josh/smb
    #sudo -u josh systemctl --user enable smbnetfs
fi

if which bluetoothctl
then
    echo "### Configuring Bluetooth..."
    cat << EOF >> /etc/bluetooth/main.conf

[Policy]
AutoEnable=true
EOF
    systemctl enable bluetooth.service
fi

echo "### Configuring UPS..."
which apcaccess && systemctl enable apcupsd.service

echo "### Configuring Sensors..."
sensors-detect --auto

if [[ "${HAS_GUI}" == "1" ]]
then
    echo "### Configuring Xorg..."
    which ratbagd && systemctl enable ratbagd.service
    for d in "${SEAT1_DEVICES[@]}"
    do
        loginctl attach seat1 "${d}"
    done

    echo "### Configuring Fonts..."
    ln -sf ../conf.avail/75-joypixels.conf /etc/fonts/conf.d/75-joypixels.conf

    echo "### Fetching MS Fonts..."
    scp root@beast:/mnt/d/bulk/Software/MSDN/Windows/WindowsFonts.tar.bz2 /tmp/
    cd /usr/share/fonts
    tar xf /tmp/WindowsFonts.tar.bz2
    chmod 755 WindowsFonts

    echo "### Configuring Display Manager..."
    case ${USE_DM} in
    gdm)
        systemctl enable gdm.service
        ;;
    sddm)
        systemctl enable sddm.service
        [[ "${HAS_OPTIMUS}" == "1" ]] && cat << EOF >> /etc/sddm.conf.d/display.conf
xrandr --setprovideroutputsource modesetting NVIDIA-0
xrandr --auto
EOF
        ;;
    esac
    systemctl enable xvnc.socket
fi

echo "### Configuring Steam..."
if [[ -d /bulk ]]
then
    mkdir -p /bulk/steam
    chown gustafson:gustafson /bulk/steam
fi

if which virsh
then
    echo "### Configuring KVM..."
    systemctl enable --now libvirtd.service
    virsh net-define "$(cd "$(dirname "$0")" ; pwd)/${HOSTNAME}/libvirt/internal-network.xml"
    virsh net-autostart internal
    virsh net-start internal
    cat << EOF >> /etc/libvirt/qemu.conf
nvram = [
    "/usr/share/ovmf/x64/OVMF_CODE.fd:/usr/share/ovmf/x64/OVMF_VARS.fd"
]
EOF
fi

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
rm /etc/systemd/system/getty@tty1.service.d/override.conf

echo "### Making a snapshot..."
for pool in z/root z/home z/images
do
    zfs snapshot ${pool}@post-boot-install
done

echo "### Installing AUR Packages (interactive)..."
sudo -u builder yay -S --needed "${AUR_PACKAGES[@]}"

echo "### Configuring AUR Xorg..."
[[ "${HAS_OPTIMUS}" == "1" ]] && systemctl enable optimus-manager.service

echo "### Configuring Printing..."
systemctl enable org.cups.cupsd.service

echo "### Configuring ZFS Snapshots..."
# /etc/systemd/system/zfs-auto-snapshot-*.service.d
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
if [[ "${HAS_DOCKER}" == "1" ]]
then
    usermod -a -G docker josh
    systemctl enable docker.service
    systemctl enable docker-prune.timer
fi

echo "### Cleaning up..."
rm -rf /install

echo "### Making a snapshot..."
for pool in z/root z/home z/docker z/images
do
    zfs snapshot ${pool}@aur-packages-installed
done

echo "### Done with post-boot install! Rebooting..."
reboot
