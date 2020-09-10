#!/bin/bash -e

# curl -s https://jgus.github.io/install/init.sh | bash

echo "### Adding packages..."
if which apt
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
elif which pacman 
then
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

echo "### System prep complete; SSH available at:"
ip a | grep inet
