#!/usr/bin/env bash

set -e

apt -y install apcupsd

cat <<EOF >/etc/apcupsd/apcupsd.conf
## apcupsd.conf v1.1 ##

UPSCABLE usb
UPSTYPE usb
DEVICE 

ONBATTERYDELAY 3
BATTERYLEVEL 10
MINUTES 5
TIMEOUT 0
EOF

echo "ISCONFIGURED=yes" > /etc/default/apcupsdÍ
