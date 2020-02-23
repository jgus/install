#!/bin/bash
set -e

# TODO
# vnc?
# https://wiki.archlinux.org/index.php/Fan_speed_control#Fancontrol_(lm-sensors)

HOSTNAME=$(hostname)
source "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/config.env

echo "### Configuring users..."
useradd -D --shell /bin/zsh

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

# echo "### Configuring power..."
# # common/files/etc/skel/.config/powermanagementprofilesrc
# [[ "${ALLOW_POWEROFF}" == "1" ]] || cat << EOF >>/etc/polkit-1/rules.d/10-disable-shutdown.rules
# polkit.addRule(function(action, subject) {
#     if (action.id == "org.freedesktop.login1.reboot" ||
#         action.id == "org.freedesktop.login1.reboot-multiple-sessions" ||
#         action.id == "org.freedesktop.login1.power-off" ||
#         action.id == "org.freedesktop.login1.power-off-multiple-sessions")
#     {
#         if (subject.isInGroup("sudo")) {
#             return polkit.Result.YES;
#         } else {
#             return polkit.Result.NO;
#         }
#     }
# });
# EOF
# [[ "${ALLOW_SUSPEND}" == "1" ]] || cat << EOF >>/etc/polkit-1/rules.d/10-disable-suspend.rules
# polkit.addRule(function(action, subject) {
#     if (action.id == "org.freedesktop.login1.suspend" ||
#         action.id == "org.freedesktop.login1.suspend-multiple-sessions" ||
#         action.id == "org.freedesktop.login1.hibernate" ||
#         action.id == "org.freedesktop.login1.hibernate-multiple-sessions")
#     {
#         return polkit.Result.NO;
#     }
# });
# EOF

# if which bluetoothctl
# then
#     echo "### Configuring Bluetooth..."
#     cat << EOF >> /etc/bluetooth/main.conf

# [Policy]
# AutoEnable=true
# EOF
#     systemctl enable bluetooth.service
# fi

# echo "### Configuring UPS..."
# which apcaccess && systemctl enable apcupsd.service

# echo "### Configuring Sensors..."
# sensors-detect --auto

if [[ "${HAS_GUI}" == "1" ]]
then
    echo "### Configuring Xorg..."
    which ratbagd && systemctl enable ratbagd.service
    for d in "${SEAT1_DEVICES[@]}"
    do
        loginctl attach seat1 "${d}"
    done

    echo "### Configuring Fonts..."
    ln -sf ../conf.avail/75-joypixels.conf /etc/fonts/conf.d/75-joypixels.conf

    echo "### Fetching MS Fonts..."
    scp root@beast:/mnt/d/bulk/Software/MSDN/Windows/WindowsFonts.tar.bz2 /tmp/
    cd /usr/share/fonts
    tar xf /tmp/WindowsFonts.tar.bz2
    chmod 755 WindowsFonts

    echo "### Configuring Display Manager..."
    case ${USE_DM} in
    gdm)
        systemctl enable gdm.service
        ;;
    sddm)
        systemctl enable sddm.service
        [[ "${HAS_OPTIMUS}" == "1" ]] && cat << EOF >> /etc/sddm.conf.d/display.conf
xrandr --setprovideroutputsource modesetting NVIDIA-0
xrandr --auto
EOF
        ;;
    esac
    systemctl enable xvnc.socket
fi

if which virsh
then
    echo "### Configuring KVM..."
    systemctl enable --now libvirtd.service
    virsh net-define "$(cd "$(dirname "$0")" ; pwd)/${HOSTNAME}/libvirt/internal-network.xml"
    virsh net-autostart internal
    virsh net-start internal
    cat << EOF >> /etc/libvirt/qemu.conf
nvram = [
    "/usr/share/ovmf/x64/OVMF_CODE.fd:/usr/share/ovmf/x64/OVMF_VARS.fd"
]
EOF
fi

echo "### TODO!!! ###"
false

echo "### Configuring Environment..."
cat <<EOF >>/etc/profile
export EDITOR=nano
EOF

echo "### Making a snapshot..."
for pool in root/root root/home root/images
do
    zfs snapshot ${pool}@post-boot-install
done

echo "### Configuring AUR Xorg..."
[[ "${HAS_OPTIMUS}" == "1" ]] && systemctl enable optimus-manager.service

echo "### Configuring Printing..."
systemctl enable org.cups.cupsd.service

echo "### Configuring ZFS Snapshots..."
# /etc/systemd/system/zfs-auto-snapshot-*.service.d
for i in monthly weekly daily hourly frequent
do
    systemctl enable zfs-auto-snapshot-${i}.timer
done

echo "### Configuring Docker..."
#/etc/docker/daemon.json
if [[ "${HAS_DOCKER}" == "1" ]]
then
    usermod -a -G docker josh
    systemctl enable docker.service
    systemctl enable docker-prune.timer
fi

echo "### Cleaning up..."
rm -rf /install

echo "### Making a snapshot..."
for pool in root/root root/home root/docker root/images
do
    zfs snapshot ${pool}@aur-packages-installed
done

echo "### Done with post-boot install! Rebooting..."
reboot
