#!/bin/bash

GAMES_PACKAGES+=(
    dosbox
    #scummvm
    #retroarch
    #dolphin-emu
    steam steam-native-runtime ttf-liberation steam-fonts
    minecraft-launcher

    # Gamepad
    #xboxdrv
    evtest
)

if ((HAS_GUI))
then
    install "${GAMES_PACKAGES[@]}"
fi
