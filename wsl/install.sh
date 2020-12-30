#!/bin/bash -e

SCRIPT_DIR="$(cd "$(dirname "$0")" ; pwd)"

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

cd "${SCRIPT_DIR}"/install
for f in *.sh
do
    cd "${SCRIPT_DIR}"/install
    tag="${f%.*}"
    if ! [ -f "${SCRIPT_DIR}/.installed/${tag}" ]
    then
        echo "### Install: ${tag}..."
        source ${f}
        touch "${SCRIPT_DIR}/.installed/${tag}"
    fi
done

echo "### Done with install!"
