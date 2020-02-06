#!/usr/bin/env bash

set -e

#tasksel install xubuntu-core
apt -y install xfce4 xfce4-goodies
apt -y install tigervnc-standalone-server

cat <<EOF >>/etc/vnc.conf
$localhost = "no";
EOF

cat <<EOF | vncpasswd /home/vncpasswd
{passwd}
{passwd}
n
EOF

cat <<EOF >>/etc/lightdm/lightdm.conf.d/vnc.conf
[VNCServer]
enabled=true
command=Xvnc -PasswordFile /home/vncpasswd
port=5900
width=1024
height=768
depth=24
EOF

service lightdm restart
