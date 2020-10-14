#!/bin/bash

XORG_AUR_PACAKGES+=(
    xbanish
    openscad-mcad-dev-git
)

if ((HAS_GUI))
then
    install "${XORG_AUR_PACAKGES[@]}"
    if ((HAS_OPTIMUS))
    then
        install optimus-manager optimus-manager-qt
        systemctl enable optimus-manager.service
    fi
fi

