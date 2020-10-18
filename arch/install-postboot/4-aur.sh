#!/bin/bash

AUR_PACKAGES+=(
    # Bootloader
    systemd-boot-pacman-hook
)

install "${AUR_PACKAGES[@]}"
