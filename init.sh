#!/bin/bash -e

# bash <(curl -s https://jgus.github.io/install/init.sh)

echo "### Adding packages..."
if command -v apt
then
    PACKAGES=(
        debootstrap
        gdisk
        efivar
        zfsutils-linux
        openssh-server
        curl
    )
    apt-add-repository universe
    apt update
    apt install --yes "${PACKAGES[@]}"
elif command -v pacman 
then
    PACKAGES=(
        git
    )
    pacman -Sy --needed --noconfirm "${PACKAGES[@]}"
    curl -s https://eoli3n.github.io/archzfs/init | bash
fi

echo "### Setting up SSH..."
mkdir -p ~/.ssh || true
touch ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
curl https://github.com/jgus.keys >> ~/.ssh/authorized_keys
uniq -i ~/.ssh/authorized_keys
chmod 400 ~/.ssh/authorized_keys

systemctl start ssh || systemctl start sshd

echo "### Cloning repo..."
git clone https://github.com/jgus/install

echo "### System prep complete; SSH available at:"
ip a | grep inet
