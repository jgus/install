#!/bin/bash

PACKAGES+=(
    apt-file
    git git-lfs
    p7zip-full p7zip-rar tmux
    rng-tools
    ntp
    samba
    speedtest-cli
    zsh

    smbnetfs sshfs fuseiso ntfs-3g dislocker

    gnome-tweak-tool

    ## KDE
    #kde-full

    # Wine
    wine winetricks
    # Applications
    code
    remmina remmina-plugin-rdp remmina-plugin-vnc
    libreoffice
    gparted
    # Media
    vlc
    mkvtoolnix mkvtoolnix-gui
    youtube-dl
    gimp
    rawtherapee hugin digikam libimage-exiftool-perl
    audacity
    # Modeling
    openscad
    blender
    prusa-slicer
    cura

    # NVidia
    system76-cuda-latest

    # Java
    openjdk-8-jre openjdk-11-jre openjdk-15-jdk icedtea-netx

    # Games
    steam
)

export DEBIAN_FRONTEND=noninteractive
apt update
apt upgrade --yes --allow-downgrades
apt autoremove --yes

install "${PACKAGES[@]}"
apt-file update
