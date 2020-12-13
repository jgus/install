#!/bin/bash -e

SCRIPT_DIR="$(cd "$(dirname "$0")" ; pwd)"

HOSTNAME=$(hostname)
source "${SCRIPT_DIR}/${HOSTNAME}/config.env"

install() {
    export DEBIAN_FRONTEND=noninteractive
    apt install --yes "$@"
}

cd "${SCRIPT_DIR}"/install-postboot
for f in *
do
    cd "${SCRIPT_DIR}"/install-postboot
    tag="${f%.*}"
    if ! zfs list z/root@post-boot-install-${tag}
    then
        echo "### Post-boot Install: ${tag}..."
        source ${f}
        zfs snapshot z/root@post-boot-install-${tag}
    fi
done

if [[ -d "${SCRIPT_DIR}"/${HOSTNAME}/install-postboot ]]
then
    cd "${SCRIPT_DIR}"/${HOSTNAME}/install-postboot
    for f in *
    do
        cd "${SCRIPT_DIR}"/${HOSTNAME}/install-postboot
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
