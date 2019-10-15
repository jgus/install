#!/bin/bash
set -e

DEVICE="$1"
if [[ "${DEVICE}" == "" ]]
then
    echo "No device specified"
    exit 1
fi

if [[ ! -d ~/archlive/out ]]
then
    mount -o remount,size=8G /run/archiso/cowspace

    echo "### Ranking mirrors..."
    pacman -Sy --needed --noconfirm pacman-contrib
    curl -s "https://www.archlinux.org/mirrorlist/?country=US&protocol=https&use_mirror_status=on" | sed -e 's/^#Server/Server/' -e '/^#/d' | rankmirrors -n 5 - >/etc/pacman.d/mirrorlist

    echo "### Adding packages..."
    if ! grep -q archzfs /etc/pacman.conf
    then
        cat << EOF >>/etc/pacman.conf

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
    rm -rf ~/archlive
    cp -r /usr/share/archiso/configs/releng ~/archlive

    cat << EOF >>~/archlive/pacman.conf

[archzfs]
Server = https://archzfs.com/\$repo/\$arch
EOF

    cat << EOF >>~/archlive/packages.x86_64
base-devel
dkms
linux-headers
git
pacman-contrib
zfs-dkms
EOF

    # for file in ~/archlive/efiboot/loader/entries/archiso-*.conf
    # do
    #     sed -i 's/options \(.*\)/options nomodeset=1 \1/g' "${file}"
    # done

    cd ~/archlive/airootfs/root
    git clone https://github.com/jgus/install
    mkdir -p ~/archlive/airootfs/root/.ssh
    touch ~/archlive/airootfs/root/.ssh/authorized_keys
    chmod 600 ~/archlive/airootfs/root/.ssh/authorized_keys
    curl https://github.com/jgus.keys >> ~/archlive/airootfs/root/.ssh/authorized_keys
    chmod 400 ~/archlive/airootfs/root/.ssh/authorized_keys

    cat << EOF >>~/archlive/airootfs/root/customize_airootfs.sh

systemctl enable sshd.service
EOF

    cat << EOF >>~/archlive/airootfs/root/.zlogin
if [[ -x ~/.runonce.sh ]]
then
    rm -f ~/.running.sh
    mv ~/.runonce.sh ~/.running.sh
    ~/.running.sh
    rm -f ~/.running.sh
fi
EOF

    cat << EOF >>~/archlive/airootfs/root/.runonce.sh
#!/bin/bash
set -e
pacman-key --init
pacman-key -r F75D9D76
pacman-key --lsign-key F75D9D76
pacman -Sy
cd ~/install
git pull
EOF
    chmod a+x ~/archlive/airootfs/root/.runonce.sh

    echo "### Building image..."
    cd ~/archlive
    ./build.sh -v
fi

ISO=$(ls -1 ~/archlive/out/*)

echo "### Wiping recovery device..."
wipefs --all "${DEVICE}"
echo "### Flashing recovery device..."
dd bs=4M if="${ISO}" of="${DEVICE}" status=progress oflag=sync

echo "Done creating recovery key!"
