#!/bin/bash

if ((HAS_BLUETOOTH))
then
    install bluez bluez-utils bluez-plugins
    cat << EOF >> /etc/bluetooth/main.conf

[Policy]
AutoEnable=true
EOF

    echo "options bluetooth disable_ertm=1" >/etc/modprobe.d/xbox_bt.conf

    systemctl enable bluetooth.service
fi
