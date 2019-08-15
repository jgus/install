#!/bin/bash
set -e

mount -o remount,size=8G /run/archiso/cowspace

pacman -Sy --needed --noconfirm pacman-contrib
curl -s "https://www.archlinux.org/mirrorlist/?country=US&protocol=https&use_mirror_status=on" | sed -e 's/^#Server/Server/' -e '/^#/d' | rankmirrors -n 5 - >/etc/pacman.d/mirrorlist

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
pacman -S --needed --noconfirm base-devel archiso git

rm -rf ~/archiso
cp -r /usr/share/archiso/configs/releng ~/archiso

cat <<EOF >>~/archiso/pacman.conf

[archzfs]
Server = https://archzfs.com/\$repo/\$arch
EOF

cat <<EOF >>~/archiso/packages.x86_64
archzfs-linux
git
pacman-contrib
EOF

for file in ~/archiso/efiboot/loader/entries/archiso-*.conf
do
    sed -i 's/options \(.*\)/options nomodeset=1 \1/g' "${file}"
done

cd ~/archiso/airootfs/root
git clone https://github.com/jgus/install
mkdir -p ~/archiso/airootfs/root/.ssh
touch ~/archiso/airootfs/root/.ssh/authorized_keys
chmod 600 ~/archiso/airootfs/root/.ssh/authorized_keys
curl https://github.com/jgus.keys >> ~/archiso/airootfs/root/.ssh/authorized_keys
chmod 400 ~/archiso/airootfs/root/.ssh/authorized_keys

cat <<EOF >>~/archiso/airootfs/root/customize_airootfs.sh

systemctl enable sshd.socket
EOF

cat <<EOF >>~/archiso/airootfs/root/add-keys.sh

pacman-key --init
pacman-key -r F75D9D76
pacman-key --lsign-key F75D9D76
pacman -Sy
EOF
chmod a+x ~/archiso/airootfs/root/add-keys.sh

cd ~/archiso
./build.sh -v
