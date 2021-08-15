#!/bin/bash -e

# echo "### TEMP!!!"
# zsh


# TODO
# vnc?
# https://wiki.archlinux.org/index.php/Fan_speed_control#Fancontrol_(lm-sensors)

SCRIPT_DIR="$(cd "$(dirname "$0")" ; pwd)"

HOSTNAME=$(hostname)
source "${SCRIPT_DIR}/${HOSTNAME}/config.env"

lspci | grep NVIDIA && HAS_NVIDIA=1
lspci | grep AMD | grep VGA && HAS_AMD=1

install() {
    if [[ -f /usr/bin/yay ]]
    then
        yes '' | sudo -u builder /usr/bin/yay -Syu --needed "$@"
    else
        pacman -Syu --needed --noconfirm "$@"
    fi
}

while ! pacman -Syy
do
    echo "Failed to update packages; will retry..."
    sleep 1
done

cd "${SCRIPT_DIR}"/install-postboot
for f in *
do
    cd "${SCRIPT_DIR}"/install-postboot
    tag="${f%.*}"
    if ! lvdisplay vg/root.post-boot-install-${tag}
    then
        echo "### Post-boot Install: ${tag}..."
        source ${f}
        btrfs subvolume snapshot -r / /.snap/post-boot-install-${tag}
    fi
done

if [[ -d "${SCRIPT_DIR}"/${HOSTNAME}/install-postboot ]]
then
    cd "${SCRIPT_DIR}"/${HOSTNAME}/install-postboot
    for f in *
    do
        cd "${SCRIPT_DIR}"/${HOSTNAME}/install-postboot
        tag="${f%.*}"
        if ! lvdisplay vg/root.post-boot-install-${tag}
        then
            echo "### Machine Post-boot Install: ${tag}..."
            source ${f}
            btrfs subvolume snapshot -r / /.snap/post-boot-install-${tag}
        fi
    done
fi

if ! lvdisplay vg/root.post-boot-cleanup
then
    echo "### Cleaning up..."
    rm /etc/systemd/system/getty@tty1.service.d/override.conf
    rm -rf /install

    btrfs subvolume snapshot -r / /.snap/post-boot-cleanup
fi

echo "### Done with post-boot install! Rebooting..."
reboot
