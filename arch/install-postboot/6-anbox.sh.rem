#!/bin/bash

cat << EOF > /etc/tmpfiles.d/anbox.conf
d! /dev/binderfs 0755 root root
EOF

cat << EOF >> /etc/fstab

# anbox/binderfs
none /dev/binderfs binder nofail 0 0
EOF

install anbox-git anbox-image-gapps-rooted

systemctl enable anbox-container-manager

nmcli con add type bridge ifname anbox0 -- connection.id anbox-net ipv4.method shared ipv4.addresses 192.168.250.1/24
