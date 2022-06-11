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

cat << EOF >/etc/dhcpcd.conf
slaac private

interface eth0
static ip_address=172.22.0.2/16
static routers=172.22.0.1
static domain_name_servers=127.0.0.1
EOF
