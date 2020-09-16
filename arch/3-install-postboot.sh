#!/bin/bash -e

# echo "### TEMP!!!"
# zsh


# TODO
# vnc?
# https://wiki.archlinux.org/index.php/Fan_speed_control#Fancontrol_(lm-sensors)

HOSTNAME=$(hostname)
source "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/config.env
KERNEL=${KERNEL:-linux}

PACKAGES+=(
    # RNG
    rng-tools
    # Pacman
    pacman-contrib reflector
    # LDAP Auth
    openldap nss-pam-ldapd sssd
    # Sensors
    lm_sensors nvme-cli
    # General
    git git-lfs
    diffutils inetutils less logrotate man-db man-pages nano usbutils which
    # OpenSSH
    openssh
    # Samba
    samba
    # Misc
    ccache rsync p7zip tmux
    )
((HAS_BLUETOOTH)) && PACKAGES+=(
    # Bluetooth
    bluez bluez-utils bluez-plugins
    )
((HAS_GUI)) && PACKAGES+=(
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
((HAS_NVIDIA)) && PACKAGES+=(
    nvidia-utils lib32-nvidia-utils nvidia-settings
    opencl-nvidia ocl-icd cuda clinfo
    )
((HAS_DOCKER)) && PACKAGES+=(
    docker
    )

AUR_PACKAGES+=(
    # Bootloader
    systemd-boot-pacman-hook
    # ZFS
    zfs-auto-snapshot
    )
((HAS_GUI)) && AUR_PACKAGES+=(
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
((HAS_OPTIMUS)) && AUR_PACKAGES+=(
    optimus-manager optimus-manager-qt
    )
((HAS_DOCKER)) && ((HAS_NVIDIA)) && AUR_PACKAGES+=(
    nvidia-container-toolkit
    )

if ! zfs list z/root@post-boot-install-packages
then
    echo "### Installing packages..."
    pacman -Syyu --needed --noconfirm "${PACKAGES[@]}"
    systemctl enable reflector.timer

    zfs snapshot z/root@post-boot-install-packages
fi

if ! zfs list z/root@post-boot-install-rng
then
    echo "### Configuring RNG..."
    systemctl enable --now rngd.service

    zfs snapshot z/root@post-boot-install-rng
fi

# echo "### Configuring power..."
# # common/files/etc/skel/.config/powermanagementprofilesrc
# ((ALLOW_POWEROFF)) || cat << EOF >>/etc/polkit-1/rules.d/10-disable-shutdown.rules
# polkit.addRule(function(action, subject) {
#     if (action.id == "org.freedesktop.login1.reboot" ||
#         action.id == "org.freedesktop.login1.reboot-multiple-sessions" ||
#         action.id == "org.freedesktop.login1.power-off" ||
#         action.id == "org.freedesktop.login1.power-off-multiple-sessions")
#     {
#         if (subject.isInGroup("wheel")) {
#             return polkit.Result.YES;
#         } else {
#             return polkit.Result.NO;
#         }
#     }
# });
# EOF
# ((ALLOW_SUSPEND)) || cat << EOF >>/etc/polkit-1/rules.d/10-disable-suspend.rules
# polkit.addRule(function(action, subject) {
#     if (action.id == "org.freedesktop.login1.suspend" ||
#         action.id == "org.freedesktop.login1.suspend-multiple-sessions" ||
#         action.id == "org.freedesktop.login1.hibernate" ||
#         action.id == "org.freedesktop.login1.hibernate-multiple-sessions")
#     {
#         return polkit.Result.NO;
#     }
# });
# EOF

if ! zfs list z/root@post-boot-network
then
    echo "### Configuring network..."
    if ((HAS_WIFI))
    then
        for i in /etc/NetworkManager/wifi
        do
            source "${i}"
            nmcli device wifi connect ${ssid} password ${psk}
        done
    fi

    zfs snapshot z/root@post-boot-network
fi

if ! zfs list z/root@post-boot-ldap
then
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
    source /root/.secrets/openldap.env
    echo "ldap_default_authtok = ${LDAP_ADMIN_PASSWORD}" >> /etc/sssd/sssd.conf
    chmod 600 /etc/sssd/sssd.conf
    systemctl enable --now nslcd.service
    systemctl enable --now sssd.service

    zfs snapshot z/root@post-boot-ldap
fi

if ! zfs list z/root@post-boot-ssh
then
    echo "### Configuring SSH..."
    cat << EOF >>/etc/ssh/sshd_config
PasswordAuthentication no
AllowAgentForwarding yes
AllowTcpForwarding yes
EOF
    systemctl enable sshd.service

    zfs snapshot z/root@post-boot-ssh
fi

if ! zfs list z/root@post-boot-nas
then
    echo "### Configuring NAS Shares..."
    mkdir /nas
    cat <<EOF >>/etc/fstab

# NAS
EOF
    for share in "${NAS_SHARES[@]}"
    do
        mkdir /nas/${share}
        echo "//nas/${share} /nas/${share} cifs noauto,nofail,x-systemd.automount,x-systemd.requires=network-online.target,x-systemd.device-timeout=30,credentials=/etc/samba/private/nas 0 0" >>/etc/fstab
        mount /nas/${share}
    done

    zfs snapshot z/root@post-boot-nas
fi

if ! zfs list z/root@post-boot-users
then
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

    zfs snapshot z/root@post-boot-users
fi

if ! zfs list z/root@post-boot-makepkg
then
    echo "### Configuring makepkg..."
    sed -i 's/!ccache/ccache/g' /etc/makepkg.conf
    cat <<EOF >>/etc/makepkg.conf 
MAKEFLAGS="-j$(nproc)"
BUILDDIR=/tmp/makepkg
EOF

    zfs snapshot z/root@post-boot-makepkg
fi

if ! zfs list z/root@post-boot-samba
then
    # /etc/samba/smb.conf
    # /etc/systemd/user/smbnetfs.service
    [[ -f /etc/samba/smb.conf ]] && systemctl enable smb.service
    if which smbnetfs
    then
        echo "### Configuring Samba..."
        mkdir -p /home/josh/smb
        chown -R josh:josh /home/josh/smb
        #sudo -u josh systemctl --user enable smbnetfs
    fi

    zfs snapshot z/root@post-boot-samba
fi

if ! zfs list z/root@post-boot-bluetooth
then
    if which bluetoothctl
    then
        echo "### Configuring Bluetooth..."
        cat << EOF >> /etc/bluetooth/main.conf

[Policy]
AutoEnable=true
EOF
        systemctl enable bluetooth.service
    fi

    zfs snapshot z/root@post-boot-bluetooth
fi

if ! zfs list z/root@post-boot-ups
then
    echo "### Configuring UPS..."
    which apcaccess && systemctl enable apcupsd.service

    zfs snapshot z/root@post-boot-ups
fi

if ! zfs list z/root@post-boot-sensors
then
    echo "### Configuring Sensors..."
    sensors-detect --auto

    zfs snapshot z/root@post-boot-sensors
fi

if ((HAS_GUI))
then
    if ! zfs list z/root@post-boot-xorg
    then
        echo "### Configuring Xorg..."
        which ratbagd && systemctl enable ratbagd.service
        for d in "${SEAT1_DEVICES[@]}"
        do
            loginctl attach seat1 "${d}"
        done

        zfs snapshot z/root@post-boot-xorg
    fi

    if ! zfs list z/root@post-boot-fonts
    then
        echo "### Configuring Fonts..."
        ln -sf ../conf.avail/75-joypixels.conf /etc/fonts/conf.d/75-joypixels.conf

        zfs snapshot z/root@post-boot-fonts
    fi

    # echo "### Fetching MS Fonts..."
    # scp root@nas:/mnt/d/bulk/Software/MSDN/Windows/WindowsFonts.tar.bz2 /tmp/
    # cd /usr/share/fonts
    # tar xf /tmp/WindowsFonts.tar.bz2
    # chmod 755 WindowsFonts

    if ! zfs list z/root@post-boot-dm
    then
        echo "### Configuring Display Manager..."
        case ${USE_DM} in
        gdm)
            systemctl enable gdm.service
            ;;
        sddm)
            systemctl enable sddm.service
            ((HAS_OPTIMUS)) && cat << EOF >> /etc/sddm.conf.d/display.conf
xrandr --setprovideroutputsource modesetting NVIDIA-0
xrandr --auto
EOF
            ;;
        esac

        zfs snapshot z/root@post-boot-dm
    fi

    #systemctl enable xvnc.socket
fi

if ! zfs list z/root@post-boot-steam
then
    echo "### Configuring Steam..."
    if [[ -d /bulk ]]
    then
        mkdir -p /bulk/steam
        chown gustafson:gustafson /bulk/steam
    fi

    zfs snapshot z/root@post-boot-steam
fi

if ! zfs list z/root@post-boot-virsh
then
    if which virsh
    then
        echo "### Configuring KVM..."
        systemctl enable --now libvirtd.service
        if [[ -f "$(cd "$(dirname "$0")" ; pwd)/${HOSTNAME}/libvirt/internal-network.xml" ]]
        then
            virsh net-define "$(cd "$(dirname "$0")" ; pwd)/${HOSTNAME}/libvirt/internal-network.xml"
            virsh net-autostart internal
            virsh net-start internal
        fi
        cat << EOF >> /etc/libvirt/qemu.conf
nvram = [
    "/usr/share/ovmf/x64/OVMF_CODE.fd:/usr/share/ovmf/x64/OVMF_VARS.fd"
]
EOF
    fi

    zfs snapshot z/root@post-boot-virsh
fi

if ! zfs list z/root@post-boot-yay
then
    echo "### Installing Yay..."
    useradd --user-group --home-dir /var/cache/builder --create-home --system builder
    chmod ug+ws /var/cache/builder
    setfacl -m u::rwx,g::rwx /var/cache/builder
    cd /var/cache/builder
    sudo -u builder git clone https://aur.archlinux.org/yay.git
    cd yay
    sudo -u builder makepkg -si --needed --noconfirm

    zfs snapshot z/root@post-boot-yay
fi

if ! zfs list z/root@post-boot-env
then
    echo "### Configuring Environment..."
    cat <<EOF >>/etc/profile
export EDITOR=nano
alias yay='sudo -u builder yay'
alias yayinst='sudo -u builder yay -Syu --needed'
EOF

    zfs snapshot z/root@post-boot-env
fi

if ! zfs list z/root@post-boot-aur
then
    echo "### Installing AUR Packages (interactive)..."
    sudo -u builder yay -S --needed "${AUR_PACKAGES[@]}"

    zfs snapshot z/root@post-boot-aur
fi

if ! zfs list z/root@post-boot-xorg-aur
then
    echo "### Configuring AUR Xorg..."
    ((HAS_OPTIMUS)) && systemctl enable optimus-manager.service

    zfs snapshot z/root@post-boot-xorg-aur
fi

if ! zfs list z/root@post-boot-printing
then
    echo "### Configuring Printing..."
    systemctl enable org.cups.cupsd.service

    zfs snapshot z/root@post-boot-printing
fi

if ! zfs list z/root@post-boot-znap
then
    echo "### Configuring ZFS Snapshots..."
    # /etc/systemd/system/zfs-auto-snapshot-*.service.d
    for i in monthly weekly daily hourly frequent
    do
        systemctl enable zfs-auto-snapshot-${i}.timer
    done

    zfs snapshot z/root@post-boot-znap
fi

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
# ExcludePath ^/nas/
# ExcludePath ^/home/josh/smb/

# ScanOnAccess true
# OnAccessMountPath /
# OnAccessExcludePath /proc/
# OnAccessExcludePath /sys/
# OnAccessExcludePath /dev/
# OnAccessExcludePath /run/
# OnAccessExcludePath /var/log/
# OnAccessExcludePath /nas/
# OnAccessExcludePath /home/josh/smb/
# OnAccessExtraScanning true
# OnAccessExcludeRootUID yes

# EOF
# freshclam
# clamav-unofficial-sigs.sh
# systemctl enable clamav-freshclam.service
# systemctl enable clamav-unofficial-sigs.timer
# systemctl enable clamav-daemon.service

if ! zfs list z/root@post-boot-docker
then
    echo "### Configuring Docker..."
    #/etc/docker/daemon.json
    if ((HAS_DOCKER))
    then
        usermod -a -G docker josh
        systemctl enable docker.service
        systemctl enable docker-prune.timer
    fi

    zfs snapshot z/root@post-boot-docker
fi

if ! zfs list z/root@post-boot-cleanup
then
    echo "### Cleaning up..."
    rm /etc/systemd/system/getty@tty1.service.d/override.conf
    rm -rf /install

    zfs snapshot z/root@post-boot-cleanup
fi

echo "### Done with post-boot install! Rebooting..."
reboot
