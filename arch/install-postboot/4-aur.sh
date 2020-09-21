#!/bin/bash
echo "Installing AUR pacakges: ${AUR_PACKAGES[@]}"
sudo -u builder yay -S --needed "${AUR_PACKAGES[@]}"
