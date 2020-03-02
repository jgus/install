#!/bin/bash
set -e

# TODO
# vnc?
# https://wiki.archlinux.org/index.php/Fan_speed_control#Fancontrol_(lm-sensors)

HOSTNAME=$(hostname)
source "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/config.env

HAS_GUI=${HAS_GUI:-1}

SNAPS=(
)
[[ "${HAS_GUI}" == "1" ]] && SNAPS+=(
    firefox
)
SNAPS_CLASSIC=()
[[ "${HAS_GUI}" == "1" ]] && SNAPS_CLASSIC+=(
    clion pycharm-community
)

FLATPAKS=()
[[ "${HAS_GUI}" == "1" ]] && FLATPAKS+=(
    org.bunkus.mkvtoolnix-gui
    com.makemkv.MakeMKV
    org.remmina.Remmina
    com.rawtherapee.RawTherapee
    com.dosbox.DOSBox
    org.scummvm.ScummVM
    org.libretro.RetroArch
    org.DolphinEmu.dolphin-emu
    com.slack.Slack
    us.zoom.Zoom
    com.mojang.Minecraft
    com.valvesoftware.Steam
    org.gimp.GIMP
    com.visualstudio.code.oss
)

echo "### Installing Snaps..."
apt remove -y firefox
apt autoremove -y
if [[ "${SNAPS[@]}" != "" ]]
then
    snap install "${SNAPS[@]}"
fi
for p in "${SNAPS_CLASSIC[@]}"
do
    snap install --classic "${p}"
done

echo "### Installing Flatpaks..."
chmod a+rw /var/tmp
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install -y "${FLATPAKS[@]}"

echo "### Configuring Printer Driver..."
cd /tmp
curl -L -O http://gdlp01.c-wss.com/gds/6/0100009236/06/linux-UFRII-drv-v510-usen-09.tar.gz
tar xvf linux-UFRII-drv-v510-usen-09.tar.gz
{ echo y ; echo n ; } | ./linux-UFRII-drv-v510-usen/install.sh

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

if [[ "${HAS_GUI}" == "1" ]]
then
    echo "### Configuring Xorg..."
    which ratbagd && systemctl enable ratbagd.service
    for d in "${SEAT1_DEVICES[@]}"
    do
        loginctl attach seat1 "${d}"
    done
fi

if [[ "${HAS_OPTIMUS}" == "1" ]]
then
    echo "### Configuring Optimus..."
    cat << EOF >> /etc/sddm.conf.d/display.conf
xrandr --setprovideroutputsource modesetting NVIDIA-0
xrandr --auto
EOF
    systemctl enable optimus-manager.service
fi

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
