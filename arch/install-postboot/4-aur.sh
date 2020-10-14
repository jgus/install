#!/bin/bash

install() {
    sudo -u builder /usr/bin/yay -S --needed "$@"
}

AUR_PACKAGES+=(
    # Bootloader
    systemd-boot-pacman-hook
)

install "${AUR_PACKAGES[@]}"
