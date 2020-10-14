#!/bin/bash

if ((HAS_BLUETOOTH))
then
    install bluez bluez-utils bluez-plugins
    cat << EOF >> /etc/bluetooth/main.conf

[Policy]
AutoEnable=true
EOF
    systemctl enable bluetooth.service
fi
