#!/bin/bash

PACKAGES+=(
    git git-lfs
    diffutils inetutils less logrotate man-db man-pages nano usbutils which
    ccache rsync p7zip tmux htop
)

install pacman-contrib reflector
systemctl enable reflector.timer

install "${PACKAGES[@]}"
