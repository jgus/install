#!/bin/bash
set -e

# TODO
# vnc?
# https://wiki.archlinux.org/index.php/Fan_speed_control#Fancontrol_(lm-sensors)

HOSTNAME=$(hostname)
source "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/config.env

TIME_ZONE=${TIME_ZONE:-US/Mountain}
HAS_GUI=${HAS_GUI:-1}

PPAS+=(
)

PACKAGES+=(
    unattended-upgrades
    docker.io
    libvirt-clients qemu-system-x86 qemu-utils
    gcc gdb cmake ninja-build
    python python-pip python-virtualenv
    python3 python3-pip python3-virtualenv
    flatpak plasma-discover-flatpak-backend
    speedtest-cli
)
[[ "${HAS_GUI}" == "1" ]] && PACKAGES+=(
    kubuntu-desktop
    virt-manager
    displaycal colord colord-kde
    playonlinux winetricks
    hugin libimage-exiftool-perl digikam
    openjdk-8-jdk openjdk-14-jdk icedtea-netx
    tigervnc-standalone-server
    gimp
    clion pycharm-community
)

FLATPAKS+=()
[[ "${HAS_GUI}" == "1" ]] && FLATPAKS+=(
    com.valvesoftware.Steam
    com.visualstudio.code.oss
)

echo "### Installing pacakages..."
export DEBIAN_FRONTEND=noninteractive
curl -s https://s3.eu-central-1.amazonaws.com/jetbrains-ppa/0xA6E8698A.pub.asc | apt-key add -
echo "deb http://jetbrains-ppa.s3-website.eu-central-1.amazonaws.com bionic main" >/etc/apt/sources.list.d/jetbrains-ppa.list
for ppa in "${PPAS[@]}"
do
    add-apt-repository -y ${ppa}
done
apt update
apt upgrade --yes
apt install --yes "${PACKAGES[@]}"
apt install --yes $(check-language-support -l en_US)
apt autoremove --yes
apt-file update
patch -i /etc/apt/apt.conf.d/50unattended-upgrades.patch /etc/apt/apt.conf.d/50unattended-upgrades
rm /etc/apt/apt.conf.d/50unattended-upgrades.patch

echo "### Configuring clock..."
timedatectl set-timezone "${TIME_ZONE}"

echo "### Configuring locale..."
locale-gen en_US
locale-gen en_US.utf8
update-locale LANG=en_US.UTF-8 LC_MESSAGES=POSIX

echo "### Updating drivers..."
ubuntu-drivers autoinstall

if [[ "${HAS_OPTIMUS}" == "1" ]]
then
    echo "### Configuring PRIME..."
    prime-select on-demand
    # TODO: Add __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia
fi

echo "### Configuring Docker..."
#/etc/docker/daemon.json
systemctl enable docker-prune.timer

echo "### Configuring KVM..."
cat << EOF >> /etc/libvirt/qemu.conf
nvram = [
    "/usr/share/ovmf/OVMF.fd:/usr/share/ovmf/OVMF_VARS.fd"
]
EOF

echo "### Installing Flatpaks..."
chmod a+rw /var/tmp
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
for i in {1..10}
do
    if flatpak install -y "${FLATPAKS[@]}"
    then
        break
    fi
done
flatpak install -y "${FLATPAKS[@]}"

if [[ "${HAS_GUI}" == "1" ]]
then
    echo "### Configuring Xorg..."
    which ratbagd && systemctl enable ratbagd.service
    for d in "${SEAT1_DEVICES[@]}"
    do
        loginctl attach seat1 "${d}"
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
fi

echo "### Configuring users..."
if [[ -d /bulk ]]
then
    chown -R gustafson:gustafson /bulk
    chmod 775 /bulk
    chmod g+s /bulk
    setfacl -d -m group:gustafson:rwx /bulk
fi

usermod -a -G sudo josh
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

usermod -a -G docker josh

VIRT_NET_FILE="$(cd "$(dirname "$0")" ; pwd)/${HOSTNAME}/libvirt/internal-network.xml"
if [[ -f "${VIRT_NET_FILE}" ]]
then
    echo "### Configuring KVM..."
    virsh net-define "${VIRT_NET_FILE}"
    virsh net-autostart internal
    virsh net-start internal
fi

echo "### Cleaning up..."
rm -rf /install

echo "### Making a snapshot..."
for pool in root/root root/home root/docker root/images
do
    zfs snapshot ${pool}@post-boot-install
done

echo "### Done with post-boot install!"
echo "# TODO:"
echo "# - Setup (or restore) synchthing (systemctl enable --now syncthing)"
echo "# - Enable backup (systemctl enable --now zfs-replicate.timer)"
