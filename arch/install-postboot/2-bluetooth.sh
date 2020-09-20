#!/bin/bash

if which bluetoothctl
then
    echo "### Configuring Bluetooth..."
    cat << EOF >> /etc/bluetooth/main.conf

[Policy]
AutoEnable=true
EOF
    systemctl enable bluetooth.service
fi
