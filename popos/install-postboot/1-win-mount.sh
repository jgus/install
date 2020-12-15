#!/bin/bash

[[ -f "${SCRIPT_DIR}/${HOSTNAME}/WIN0.key" ]]
[[ -f "${SCRIPT_DIR}/${HOSTNAME}/WIN1.key" ]]

install ntfs-3g dislocker
mkdir /win
mkdir /win/.dislocker
mkdir /win/data
mkdir /win/.dislocker/data
mkdir /win/system
mkdir /win/.dislocker/system
cat <<EOF >>/etc/fstab

# Windows
PARTUUID=$(blkid /dev/disk/by-partlabel/WIN0 -o value -s PARTUUID) /win/.dislocker/data fuse.dislocker recovery-password=$(cat "${SCRIPT_DIR}/${HOSTNAME}/WIN0.key"),nofail 0 0
/win/.dislocker/data/dislocker-file /win/data auto nofail 0 0
PARTUUID=$(blkid /dev/disk/by-partlabel/WIN1 -o value -s PARTUUID) /win/.dislocker/system fuse.dislocker recovery-password=$(cat "${SCRIPT_DIR}/${HOSTNAME}/WIN1.key"),nofail 0 0
/win/.dislocker/system/dislocker-file /win/system auto nofail 0 0
EOF
mount /win/.dislocker/data
mount /win/data
mount /win/.dislocker/system
mount /win/system
