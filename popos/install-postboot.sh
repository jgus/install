#!/bin/bash -e

SCRIPT_DIR="$(cd "$(dirname "$0")" ; pwd)"

HOSTNAME=$(hostname)
source "${SCRIPT_DIR}/${HOSTNAME}/config.env"

install() {
    export DEBIAN_FRONTEND=noninteractive
    apt install --yes "$@"
}

install_deb() {
    export DEBIAN_FRONTEND=noninteractive
    for url in "$@"
    do
        FILE=$(mktemp)
        curl -L -o "${FILE}.deb" "${url}"
        apt install --yes "${FILE}.deb"
        rm "${FILE}" "${FILE}.deb"
    done
}

cd "${SCRIPT_DIR}"/install-postboot
for f in *.sh
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
    for f in *.sh
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

echo "### Done with post-boot install!"
