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
    if ! snapper -c root list --columns description | grep "^post-boot-install-${tag}\s*$"
    then
        echo "### Post-boot Install: ${tag}..."
        PRE=$(snapper -c root create -t pre -p)
        source ${f}
        snapper -c root create -t post --pre-number ${PRE} --description post-boot-install-${tag}
    fi
done

if [[ -d "${SCRIPT_DIR}"/${HOSTNAME}/install-postboot ]]
then
    cd "${SCRIPT_DIR}"/${HOSTNAME}/install-postboot
    for f in *
    do
        cd "${SCRIPT_DIR}"/${HOSTNAME}/install-postboot
        tag="${f%.*}"
        if ! snapper -c root list --columns description | grep "^post-boot-install-${tag}\s*$"
        then
            echo "### Machine Post-boot Install: ${tag}..."
            PRE=$(snapper -c root create -t pre -p)
            source ${f}
            snapper -c root create -t post --pre-number ${PRE} --description post-boot-install-${tag}
        fi
    done
fi

if ! snapper -c root list --columns description | grep "^post-boot-cleanup\s*$"
then
    echo "### Cleaning up..."
    rm /etc/systemd/system/getty@tty1.service.d/override.conf
    rm -rf /install

    snapper -c root create --description post-boot-cleanup
fi

echo "### Done with post-boot install! Rebooting..."
reboot
