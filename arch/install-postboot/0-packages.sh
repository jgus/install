#!/bin/bash
pacman -Syyu --needed --noconfirm "${PACKAGES[@]}"
systemctl enable reflector.timer
