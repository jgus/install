#!/bin/bash
if ((HAS_WIFI)) && [[ -d /etc/NetworkManager/wifi ]]
then
    for i in /etc/NetworkManager/wifi
    do
        source "${i}"
        nmcli device wifi connect ${ssid} password ${psk}
    done
fi
