#!/bin/bash

install clamav clamav-daemon clamav-freshclam ssmtp

systemctl stop clamav-freshclam
freshclam
systemctl start clamav-freshclam

systemctl stop clamav-daemon.service
sed -i "s|MaxThreads.*|MaxThreads $(nproc)|g" /etc/clamav/clamd.conf
sed -i "s|MaxDirectoryRecursion.*|MaxDirectoryRecursion 100|g" /etc/clamav/clamd.conf
echo "VirusEvent /usr/local/bin/virus_event.sh" >>/etc/clamav/clamd.conf
systemctl start clamav-daemon.service

sleep 15

/usr/local/bin/clamscan-system.sh
systemctl enable clamscan-system.timer
