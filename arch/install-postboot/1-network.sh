#!/bin/bash
if ((HAS_WIFI))
then
    for i in /etc/NetworkManager/wifi
    do
        source "${i}"
        nmcli device wifi connect ${ssid} password ${psk}
    done
fi
