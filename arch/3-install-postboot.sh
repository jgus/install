#!/bin/bash -e

# echo "### TEMP!!!"
# zsh


# TODO
# vnc?
# https://wiki.archlinux.org/index.php/Fan_speed_control#Fancontrol_(lm-sensors)

HOSTNAME=$(hostname)
source "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/config.env

install() {
    if [[ -f /usr/bin/yay ]]
    then
        sudo -u builder /usr/bin/yay -S --needed "$@"
    else
        pacman -Syyu --needed --noconfirm "$@"
    fi
}

while ! pacman -Syy
do
    echo "Failed to update packages; will retry..."
    sleep 1
done

cd "$(dirname "$0")"/install-postboot
for f in *
do
    cd "$(dirname "$0")"/install-postboot
    tag="${f%.*}"
    if ! zfs list z/root@post-boot-install-${tag}
    then
        echo "### Post-boot Install: ${tag}..."
        source ${f}
        zfs snapshot z/root@post-boot-install-${tag}
    fi
done

if [[ -d "$(dirname "$0")"/${HOSTNAME}/install-postboot ]]
then
    cd "$(dirname "$0")"/${HOSTNAME}/install-postboot
    for f in *
    do
        cd "$(dirname "$0")"/${HOSTNAME}/install-postboot
        tag="${f%.*}"
        if ! zfs list z/root@post-boot-install-${tag}
        then
            echo "### Machine Post-boot Install: ${tag}..."
            source ${f}
            zfs snapshot z/root@post-boot-install-${tag}
        fi
    done
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
