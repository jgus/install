#!/usr/bin/env -S bash -e

SCRIPT_DIR="$(cd "$(dirname "$0")" ; pwd)"

echo "Hello world from ${SCRIPT_DIR}"

PACKAGES=(
    tmux
    speedtest-cli
    git
)

export DEBIAN_FRONTEND=noninteractive
apt update
apt upgrade --yes --allow-downgrades
apt install --yes "${PACKAGES[@]}"

bash <(curl -sSL https://install.pi-hole.net)
