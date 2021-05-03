#!/bin/bash

SYSTEM76_PACKAGES+=(
    system76-driver
    system76-dkms
    system76-io-dkms
    system76-firmware
    system76-firmware-daemon
    system76-power
)


install "${SYSTEM76_PACKAGES[@]}"
systemctl enable --now system76
systemctl enable --now system76-power
systemctl enable --now system76-firmware-daemon
