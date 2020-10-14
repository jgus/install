#!/bin/bash

install clamav
#install clamav-unofficial-sigs

freshclam
# clamav-unofficial-sigs.sh
systemctl enable --now clamav-freshclam.service
# systemctl enable clamav-unofficial-sigs.timer

sed -i "s|MaxThreads.*|MaxThreads $(nproc)|g" /etc/clamav/clamd.conf
sed -i "s|MaxDirectoryRecursion.*|MaxDirectoryRecursion 100|g" /etc/clamav/clamd.conf
echo "VirusEvent /usr/local/bin/virus_event.sh" >>/etc/clamav/clamd.conf
systemctl enable --now clamav-daemon.service

/usr/local/bin/clamscan-system.sh
systemctl enable clamscan-system.timer
