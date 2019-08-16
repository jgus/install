#!/bin/bash
set -e

DEVICE="$1"
if [[ "${DEVICE}" == "" ]]
then
    (>&2 echo "No device specified")
    exit 1
fi
ISO=$(ls -1 ~/archiso/out/*)

pacman -Sy --needed --noconfirm rng-tools
systemctl enable rngd.service

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

mkfs.ext2 -L KEYS "${DEVICE}-part3"
umount /keys || true
mkdir -p /keys
mount "/dev/disk/by-label/KEYS" /keys
for i in {1..1023}
do
    dd bs=1 count=16 if=/dev/random of=/keys/"$(printf '0%03x' ${i})"
    dd bs=1 count=32 if=/dev/random of=/keys/"$(printf '1%03x' ${i})"
    dd bs=1 count=64 if=/dev/random of=/keys/"$(printf '2%03x' ${i})"
    dd bs=1 count=128 if=/dev/random of=/keys/"$(printf '3%03x' ${i})"
done
umount /keys
