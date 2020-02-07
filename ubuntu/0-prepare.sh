#!/bin/bash
set -e

# sudo -i
# git clone https://github.com/jgus/install

echo "### Adding packages..."
PACKAGES=(
    debootstrap
    gdisk
    zfsutils-linux
    openssh-server
)
apt-add-repository universe
apt update
apt install --yes "${PACKAGES[@]}"

mkdir -p ~/.ssh || true
touch ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
curl https://github.com/jgus.keys >> ~/.ssh/authorized_keys
uniq -i ~/.ssh/authorized_keys
chmod 400 ~/.ssh/authorized_keys

systemctl start ssh

echo "### System prep complete; SSH available at:"
ip a | grep inet
