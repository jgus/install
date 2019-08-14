#!/bin/bash
set -e

mount -o remount,size=8G /run/archiso/cowspace

if ! grep -q archzfs /etc/pacman.conf
then
    cat <<EOF >>/etc/pacman.conf

[archzfs]
Server = https://archzfs.com/\$repo/\$arch
EOF
    pacman-key -r F75D9D76
    pacman-key --lsign-key F75D9D76
    pacman -Syy
fi
pacman -S --needed --noconfirm base-devel archiso

rm -rf ~/archiso
cp -r /usr/share/archiso/configs/releng ~/archiso
cat <<EOF >>~/archiso/pacman.conf

[archzfs]
Server = https://archzfs.com/\$repo/\$arch
EOF
cat <<EOF >>~/archiso/packages.x86_64
archzfs-linux
EOF

cd ~/archiso
./build.sh -v
