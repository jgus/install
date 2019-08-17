#!/bin/bash
set -e

DEVICE="$1"
if [[ "${DEVICE}" == "" ]]
then
    echo "No device specified"
    exit 1
fi

if [[ ! -d ~/archiso/out ]]
then
    mount -o remount,size=8G /run/archiso/cowspace

    echo "### Ranking mirrors..."
    pacman -Sy --needed --noconfirm pacman-contrib
    curl -s "https://www.archlinux.org/mirrorlist/?country=US&protocol=https&use_mirror_status=on" | sed -e 's/^#Server/Server/' -e '/^#/d' | rankmirrors -n 5 - >/etc/pacman.d/mirrorlist

    echo "### Adding packages..."
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
    pacman -S --needed --noconfirm base-devel archiso git rng-tools
    systemctl start rngd.service

    echo "### Configuring image..."
    rm -rf ~/archiso
    cp -r /usr/share/archiso/configs/releng ~/archiso

    cat <<EOF >>~/archiso/pacman.conf

[archzfs]
Server = https://archzfs.com/\$repo/\$arch
EOF

    cat <<EOF >>~/archiso/packages.x86_64
base-devel
dkms
linux-headers
git
pacman-contrib
zfs-dkms
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

    cat <<EOF >>~/archiso/airootfs/root/.zlogin
if [[ -x ~/.runonce.sh ]]
then
    rm -f ~/.running.sh
    mv ~/.runonce.sh ~/.running.sh
    ~/.running.sh
    rm -f ~/.running.sh
fi
EOF

    cat <<EOF >>~/archiso/airootfs/root/.runonce.sh
#!/bin/bash
set -e
pacman-key --init
pacman-key -r F75D9D76
pacman-key --lsign-key F75D9D76
pacman -Sy
EOF
    chmod a+x ~/archiso/airootfs/root/.runonce.sh

    echo "### Building image..."
    cd ~/archiso
    ./build.sh -v
fi

ISO=$(ls -1 ~/archiso/out/*)

echo "### Wiping recovery device..."
wipefs --all "${DEVICE}"
echo "### Flashing recovery device..."
dd bs=4M if="${ISO}" of="${DEVICE}" status=progress oflag=sync

echo "### Adding keys..."
cat <<EOF | fdisk "${DEVICE}"
n
p
3

+1M
w
EOF
sleep 1

mkfs.ext2 -L KEYS "${DEVICE}-part3"
sleep 1
umount /keys || true
mkdir -p /keys
mount "/dev/disk/by-label/KEYS" /keys
for i in {1..63}
do
    dd bs=1 count=32 if=/dev/urandom of=/keys/"$(printf '%02x' ${i})"
done
chmod 000 /keys/*
umount /keys

echo "Done creating recovery key!"
