#!/bin/bash

PACKAGES+=(
    apt-file
    git git-lfs
    p7zip-full p7zip-rar tmux
    speedtest-cli
    zsh

    sshfs

    # Media
    mkvtoolnix
    youtube-dl

    # Java
    openjdk-8-jre openjdk-11-jre openjdk-14-jdk
)

export DEBIAN_FRONTEND=noninteractive
apt update
apt upgrade --yes --allow-downgrades
apt autoremove --yes

install "${PACKAGES[@]}"
apt-file update
