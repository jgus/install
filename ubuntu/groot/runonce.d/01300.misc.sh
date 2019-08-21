#!/usr/bin/env bash

set -e

apt -y install tmux chromium-browser net-tools

cd /tmp
wget https://go.microsoft.com/fwlink/?LinkID=760868 -O code.deb
dpkg -i *.deb
apt install -y -f
apt upgrade -y
