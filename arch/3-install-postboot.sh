#!/bin/bash -e

# echo "### TEMP!!!"
# zsh


# TODO
# vnc?
# https://wiki.archlinux.org/index.php/Fan_speed_control#Fancontrol_(lm-sensors)

HOSTNAME=$(hostname)
source "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/config.env

PACKAGES+=(
    # RNG
    rng-tools
    # Pacman
    pacman-contrib reflector
    # Sensors
    lm_sensors nvme-cli
    # General
    git git-lfs
    diffutils inetutils less logrotate man-db man-pages nano usbutils which
    # OpenSSH
    openssh
    # Samba
    samba
    # Malware
    clamav
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
    plasma-meta kde-applications-meta xdg-user-dirs packagekit-qt5
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
    firefox
    code
    freerdp
    libreoffice-still hunspell hunspell-en_US libmythes mythes-en
    scribus
    gimp
    vlc
    clamtk
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
    # Malware
    clamav-unofficial-sigs
    )
((HAS_GUI)) && AUR_PACKAGES+=(
    # Xorg
    xbanish
    # Printing
    cups cups-pdf ghostscript gsfonts cnrdrvcups-lb
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

cd "$(dirname "$0")"/install-postboot
for f in *
do
    tag="${f%.*}"
    if ! zfs list z/root@post-boot-install-${tag}
    then
        echo "### Post-boot Install: ${tag}..."
        source ${f}
        zfs snapshot z/root@post-boot-install-${tag}
    fi
done

if ! zfs list z/root@post-boot-cleanup
then
    echo "### Cleaning up..."
    rm /etc/systemd/system/getty@tty1.service.d/override.conf
    rm -rf /install

    zfs snapshot z/root@post-boot-cleanup
fi

echo "### Done with post-boot install! Rebooting..."
reboot
