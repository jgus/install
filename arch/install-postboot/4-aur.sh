#!/bin/bash

AUR_PACKAGES+=(
    # Bootloader
    systemd-boot-pacman-hook
    oh-my-zsh-git
)

install "${AUR_PACKAGES[@]}"
