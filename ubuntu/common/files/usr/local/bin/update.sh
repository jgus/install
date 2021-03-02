#!/bin/bash -e

/usr/local/bin/zfs-auto-snapshot --skip-scrub --prefix=znap --label=update --keep=14 //

export DEBIAN_FRONTEND=noninteractive
apt update
apt upgrade --yes
apt autoremove --yes

flatpak update -y

reboot
