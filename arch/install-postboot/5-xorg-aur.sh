#!/bin/bash

XORG_AUR_PACAKGES+=(
    xbanish
    openscad-mcad-dev-git
)

if ((HAS_GUI))
then
    install "${XORG_AUR_PACAKGES[@]}"
fi

