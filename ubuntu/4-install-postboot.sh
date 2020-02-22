#!/bin/bash
set -e

# TODO
# vnc?
# https://wiki.archlinux.org/index.php/Fan_speed_control#Fancontrol_(lm-sensors)

HOSTNAME=$(hostname)
source "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/config.env

PACKAGES+=(
    # sssd libpam-sss libnss-sss
)

echo "### Post-boot ZFS config..."
zfs load-key -a
for p in $(zpool list -o name -H)
do
    zpool set cachefile=/etc/zfs/zpool.cache "${p}"
done
zfs mount -a

#/etc/systemd/system/zfs-load-key.service
#/etc/systemd/system/zfs-scrub@.timer
#/etc/systemd/system/zfs-scrub@.service

systemctl enable zfs.target
systemctl enable zfs-import-cache
systemctl enable zfs-mount
systemctl enable zfs-import.target
systemctl enable zfs-load-key.service
systemctl enable zfs-scrub@root.timer
for p in $(zpool list -o name -H)
do
    systemctl enable zfs-scrub@${p}.timer
done

update-initramfs -u

echo "### Post-boot packages..."
apt update
apt install --yes "${PACKAGES[@]}"

# echo "### Configuring power..."
# # common/files/etc/skel/.config/powermanagementprofilesrc
# [[ "${ALLOW_POWEROFF}" == "1" ]] || cat << EOF >>/etc/polkit-1/rules.d/10-disable-shutdown.rules
# polkit.addRule(function(action, subject) {
#     if (action.id == "org.freedesktop.login1.reboot" ||
#         action.id == "org.freedesktop.login1.reboot-multiple-sessions" ||
#         action.id == "org.freedesktop.login1.power-off" ||
#         action.id == "org.freedesktop.login1.power-off-multiple-sessions")
#     {
#         if (subject.isInGroup("wheel")) {
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

# echo "### Configuring network..."
# if [[ "${HAS_WIFI}" == "1" ]]
# then
#     for i in /etc/NetworkManager/wifi
#     do
#         source "${i}"
#         nmcli device wifi connect ${ssid} password ${psk}
#     done
# fi

echo "### Configuring LDAP auth..."
source /root/.secrets/openldap.env
echo "ldap_default_authtok = ${LDAP_ADMIN_PASSWORD}" >> /etc/sssd/sssd.conf
sed -i "s|^/etc/ldap/ldap.conf.*|TLS_CACERT /etc/ssl/certs/ldap.crt/|g" /etc/ldap/ldap.conf
systemctl restart sssd.service

echo "### TODO!!! ###"
false

echo "### Configuring RNG..."
systemctl enable rngd.service

echo "### Configuring SSH..."
cat << EOF >>/etc/ssh/sshd_config
PasswordAuthentication no
AllowAgentForwarding yes
AllowTcpForwarding yes
EOF
systemctl enable sshd.service

echo "### Configuring Samba..."
mkdir /beast
cat <<EOF >>/etc/fstab

# Beast
EOF
for share in "${BEAST_SHARES[@]}"
do
    mkdir /beast/${share}
    echo "//beast/${share} /beast/${share} cifs noauto,nofail,x-systemd.automount,x-systemd.requires=network-online.target,x-systemd.device-timeout=30,credentials=/etc/samba/private/beast 0 0" >>/etc/fstab
    mount /beast/${share}
done

echo "### Adding system users..."
#/etc/sudoers.d/wheel
#/etc/sudoers.d/builder

useradd -D --shell /bin/zsh

if [[ -d /bulk ]]
then
    chown -R gustafson:gustafson /bulk
    chmod 775 /bulk
    chmod g+s /bulk
    setfacl -d -m group:gustafson:rwx /bulk
fi

usermod -a -G wheel josh
/etc/mkhome.sh josh

zfs create -o mountpoint=/git root/git
chown josh:josh /git

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

echo "### Configuring makepkg..."
sed -i 's/!ccache/ccache/g' /etc/makepkg.conf
cat <<EOF >>/etc/makepkg.conf 
MAKEFLAGS="-j$(nproc)"
BUILDDIR=/tmp/makepkg
EOF

echo "### Configuring Samba..."
# /etc/samba/smb.conf
# /etc/systemd/user/smbnetfs.service
[[ -f /etc/samba/smb.conf ]] && systemctl enable smb.service
if which smbnetfs
then
    mkdir -p /home/josh/smb
    chown -R josh:josh /home/josh/smb
    #sudo -u josh systemctl --user enable smbnetfs
fi

if which bluetoothctl
then
    echo "### Configuring Bluetooth..."
    cat << EOF >> /etc/bluetooth/main.conf

[Policy]
AutoEnable=true
EOF
    systemctl enable bluetooth.service
fi

echo "### Configuring UPS..."
which apcaccess && systemctl enable apcupsd.service

echo "### Configuring Sensors..."
sensors-detect --auto

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

echo "### Configuring Steam..."
if [[ -d /bulk ]]
then
    mkdir -p /bulk/steam
    chown gustafson:gustafson /bulk/steam
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

echo "### Installing Yay..."
useradd --user-group --home-dir /var/cache/builder --create-home --system builder
chmod ug+ws /var/cache/builder
setfacl -m u::rwx,g::rwx /var/cache/builder
cd /var/cache/builder
sudo -u builder git clone https://aur.archlinux.org/yay.git
cd yay
sudo -u builder makepkg -si --needed --noconfirm

echo "### Configuring Environment..."
cat <<EOF >>/etc/profile
export EDITOR=nano
alias yay='sudo -u builder yay'
alias yayinst='sudo -u builder yay -Syu --needed'
EOF

cat <<EOF
#####
#
# Please enter a root password:
#
#####
EOF
passwd

echo "### Cleaning up..."
rm /etc/systemd/system/getty@tty1.service.d/override.conf

echo "### Making a snapshot..."
for pool in root/root root/home root/images
do
    zfs snapshot ${pool}@post-boot-install
done

echo "### Installing AUR Packages (interactive)..."
sudo -u builder yay -S --needed "${AUR_PACKAGES[@]}"

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

# echo "### Configuring ClamAV..."
# sed -i 's/^User/#User/g' /etc/pacman.conf
# cat << EOF >> /etc/clamav/clamd.conf

# ### Local Settings
# User root
# MaxThreads 16
# MaxDirectoryRecursion 30
# VirusEvent /etc/clamav/detected.sh

# ExcludePath ^/proc/
# ExcludePath ^/sys/
# ExcludePath ^/dev/
# ExcludePath ^/run/
# ExcludePath ^/beast/
# ExcludePath ^/home/josh/smb/

# ScanOnAccess true
# OnAccessMountPath /
# OnAccessExcludePath /proc/
# OnAccessExcludePath /sys/
# OnAccessExcludePath /dev/
# OnAccessExcludePath /run/
# OnAccessExcludePath /var/log/
# OnAccessExcludePath /beast/
# OnAccessExcludePath /home/josh/smb/
# OnAccessExtraScanning true
# OnAccessExcludeRootUID yes

# EOF
# freshclam
# clamav-unofficial-sigs.sh
# systemctl enable clamav-freshclam.service
# systemctl enable clamav-unofficial-sigs.timer
# systemctl enable clamav-daemon.service

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
