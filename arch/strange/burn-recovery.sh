#!/bin/bash
set -e

DEVICE="$1"
if [[ "${DEVICE}" == "" ]]
then
    (>&2 echo "No device specified")
    exit 1
fi
ISO=$(ls -1 ~/archiso/out/*)

wipefs --all "${DEVICE}"
dd bs=4M if="${ISO}" of="${DEVICE}" status=progress oflag=sync

cat <<EOF | fdisk "${DEVICE}"
n
p
3

+1M
w
EOF
sleep 1

mkfs.fat -F 32 -n KEYFILE "${DEVICE}-part3"
umount /keyfile || true
mkdir -p /keyfile
mount "/dev/disk/by-label/KEYFILE" /keyfile
dd bs=1 count=32 if=/dev/random of=/keyfile/system status=progress
umount /keyfile
