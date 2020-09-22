#!/bin/bash
echo "Installing AUR pacakges: ${AUR_PACKAGES[@]}"
sudo -u builder /usr/bin/yay -S --needed "${AUR_PACKAGES[@]}"
