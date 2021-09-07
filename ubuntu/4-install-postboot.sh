#!/bin/bash -e

# TODO
# vnc?
# https://wiki.archlinux.org/index.php/Fan_speed_control#Fancontrol_(lm-sensors)

source "$(cd "$(dirname "$0")" ; pwd)"/common.sh $(hostname)

TIME_ZONE=${TIME_ZONE:-US/Mountain}
HAS_GUI=${HAS_GUI:-1}

PPAS+=(
    ppa:mscore-ubuntu/mscore3-stable
)

PACKAGES+=(
    unattended-upgrades
    docker.io
    libvirt-daemon libvirt-daemon-system libvirt-clients qemu-system-x86 qemu-utils
    tmux
    gcc gdb cmake ninja-build
    python3 python3-pip python3-virtualenv
    speedtest-cli
    ssmtp
    clamav-daemon
)
((HAS_GUI)) && PACKAGES+=(
    kubuntu-desktop kubuntu-restricted-extras
    virt-manager
    colord colord-kde
    playonlinux winetricks kdegames
    hugin libimage-exiftool-perl digikam
    openjdk-8-jdk openjdk-11-jdk icedtea-netx
    tigervnc-standalone-server
    gimp
    pycharm-community
    #steam
    musescore3
)
PACKAGES+=(
    ubuntu-drivers-common
)
DEBS+=(
    https://zoom.us/client/latest/zoom_amd64.deb
    https://go.microsoft.com/fwlink/?LinkID=760868
)
PIPS+=(
    speedtest-cli
)

export DEBIAN_FRONTEND=noninteractive

if ! zfs list rpool@post-boot-install-packages
then
    echo "### Installing packages..."
    curl -s https://s3.eu-central-1.amazonaws.com/jetbrains-ppa/0xA6E8698A.pub.asc | apt-key add -
    echo "deb http://jetbrains-ppa.s3-website.eu-central-1.amazonaws.com bionic main" >/etc/apt/sources.list.d/jetbrains-ppa.list
    for ppa in "${PPAS[@]}"
    do
        apt-add-repository -y ${ppa}
    done
    apt update
    apt upgrade --yes --allow-downgrades
    apt install --yes ${APT_EXTRA_ARGS} "${PACKAGES[@]}"
    apt install --yes ${APT_EXTRA_ARGS} $(check-language-support -l en_US)

    for deb in "${DEBS[@]}"
    do
        rm /tmp/temp.deb || true
        curl -L -o /tmp/temp.deb "${deb}"
        apt install --yes /tmp/temp.deb
        rm /tmp/temp.deb
    done

    apt autoremove --yes
    apt-file update
    patch -i /etc/apt/apt.conf.d/50unattended-upgrades.patch /etc/apt/apt.conf.d/50unattended-upgrades
    rm /etc/apt/apt.conf.d/50unattended-upgrades.patch

    pip3 install "${PIPS[@]}"

    zfs snapshot rpool@post-boot-install-packages
fi

if ! zfs list rpool@post-boot-install-locale
then
    echo "### Configuring clock..."
    timedatectl set-timezone "${TIME_ZONE}"
    
    echo "### Configuring locale..."
    locale-gen en_US
    locale-gen en_US.utf8
    update-locale LANG=en_US.UTF-8 LC_MESSAGES=POSIX
    zfs snapshot rpool@post-boot-install-locale
fi

if ! zfs list rpool@post-boot-install-drivers
then
    echo "### Updating drivers..."
    ubuntu-drivers autoinstall

    if ((HAS_OPTIMUS))
    then
        echo "### Configuring PRIME..."
        prime-select on-demand
        # TODO: Add __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia
    fi
    
    zfs snapshot rpool@post-boot-install-drivers
fi

if ! zfs list rpool@post-boot-install-docker
then
    echo "### Configuring Docker..."
    #/etc/docker/daemon.json
    systemctl enable docker
    systemctl enable docker-prune.timer
    zfs snapshot rpool@post-boot-install-docker
fi

if ! zfs list rpool@post-boot-install-kvm
then
    echo "### Configuring KVM..."
    cat << EOF >> /etc/libvirt/qemu.conf
nvram = [
    "/usr/share/ovmf/OVMF.fd:/usr/share/ovmf/OVMF_VARS.fd"
]
EOF
    
    VIRT_NET_FILE="$(cd "$(dirname "$0")" ; pwd)/${HOSTNAME}/libvirt/internal-network.xml"
    if [[ -f "${VIRT_NET_FILE}" ]]
    then
        echo "### Configuring KVM..."
        virsh net-define "${VIRT_NET_FILE}"
        virsh net-autostart internal
        virsh net-start internal
    fi
    zfs snapshot rpool@post-boot-install-kvm
fi

if ((HAS_GUI))
then
    if ! zfs list rpool@post-boot-install-gui
    then
        echo "### Configuring Xorg..."
        which ratbagd && systemctl enable ratbagd.service
        for d in "${SEAT1_DEVICES[@]}"
        do
            loginctl attach seat1 "${d}"
        done
        for d in "${SEAT2_DEVICES[@]}"
        do
            loginctl attach seat2 "${d}"
        done
        for d in "${SEAT3_DEVICES[@]}"
        do
            loginctl attach seat3 "${d}"
        done
        
        echo "### Configuring Printer Driver..."
        cd /tmp
        curl -L -O http://gdlp01.c-wss.com/gds/6/0100009236/06/linux-UFRII-drv-v510-usen-09.tar.gz
        tar xvf linux-UFRII-drv-v510-usen-09.tar.gz
        { echo y ; echo n ; } | ./linux-UFRII-drv-v510-usen/install.sh
        
        echo "### Configuring Minecraft..."
        cd /tmp
        wget https://launcher.mojang.com/download/Minecraft.deb
        apt install -y ./Minecraft.deb
        mkdir -p /etc/skel/.local/share/applications/
        cp /usr/share/applications/minecraft-launcher.desktop /etc/skel/.local/share/applications/
        sed -i "s|Exec=|Exec=env __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia |g" /etc/skel/.local/share/applications/minecraft-launcher.desktop
        zfs snapshot rpool@post-boot-install-gui
    fi
fi

if [[ -f /root/.secrets/openldap.env ]]
then
    if ! zfs list rpool@post-boot-install-users
    then
        echo "### Configuring users..."
        if [[ -d /bulk ]]
        then
            chown -R gustafson:gustafson /bulk
            chmod 775 /bulk
            chmod g+s /bulk
            setfacl -d -m group:gustafson:rwx /bulk
        fi
        
        for g in sudo plugdev docker
        do
            usermod -a -G ${g} josh
        done
        /etc/mkhome.sh josh
        
        if which virsh
        then
            usermod -a -G libvirt josh
            mkdir -p /home/josh/.config/libvirt
            echo 'uri_default = "qemu:///system"' >> /home/josh/.config/libvirt/libvirt.conf
            chown -R josh:josh /home/josh/.config/libvirt
        fi
        mkdir -p /home/josh/.ssh
        curl https://github.com/jgus.keys >> /home/josh/.ssh/authorized_keys
        chmod 400 /home/josh/.ssh/authorized_keys
        chown -R josh:josh /home/josh/.ssh
        
        zfs snapshot rpool@post-boot-install-users
    fi
fi

if [[ -f /root/.secrets/gmail.env ]]
then
    if ! zfs list rpool@post-boot-install-ssmtp
    then
        echo "### Configuring sSMTP..."
        source /root/.secrets/gmail.env
        cat <<EOF >/etc/ssmtp/ssmtp.conf
root=joshgstfsn@gmail.com
mailhub=smtp.gmail.com:587
AuthUser=joshgstfsn
AuthPass=${GMAIL_PASSWORD}
UseSTARTTLS=YES
UseTLS=YES
hostname=gustafson.me
EOF

        zfs snapshot rpool@post-boot-install-ssmtp
    fi
fi

if ! zfs list rpool@post-boot-install-clamav
then
    echo "### Configuring ClamAV..."
    sed -i "s|MaxThreads.*|MaxThreads $(nproc)|g" /etc/clamav/clamd.conf
    sed -i "s|MaxDirectoryRecursion.*|MaxDirectoryRecursion 100|g" /etc/clamav/clamd.conf
    echo "VirusEvent /usr/local/bin/virus_event.sh" >>/etc/clamav/clamd.conf
    systemctl enable --now clamav-daemon.service
    echo "### Running initial virus scan..."
    /usr/local/bin/clamscan-system.sh
    systemctl enable --now clamscan-system.timer

    zfs snapshot rpool@post-boot-install-clamav
fi

if ! zfs list rpool@post-boot-install-misc
then
    echo "### Misc..."
    sed -i "s|ENABLED=.*|ENABLED=0|g" /etc/default/motd-news

    zfs snapshot rpool@post-boot-install-misc
fi

echo "### Cleaning up..."
rm -rf /install

echo "### Making a snapshot..."
for i in monthly weekly daily hourly frequent
do
    systemctl enable zfs-auto-snapshot-${i}.timer
done
for pool in rpool
do
    zfs snapshot ${pool}@post-boot-install
done

echo "### Done with post-boot install!"
echo "# TODO:"
echo "# - Setup (or restore) synchthing (systemctl enable --now syncthing)"
echo "# - Enable backup (systemctl enable --now zfs-replicate.timer)"
