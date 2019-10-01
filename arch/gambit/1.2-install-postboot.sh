#!/bin/bash
set -e

# TODO
# vnc?
# https://wiki.archlinux.org/index.php/Fan_speed_control#Fancontrol_(lm-sensors)

OTHER_USERS=()
PACKAGES=(
    # Misc
    wget rsync p7zip tmux
    # Filesystems
    smbnetfs sshfs fuseiso
    # Sensors
    lm_sensors nvme-cli
    # Docker
    docker
)
AUR_PACKAGES=(
    # ZFS
    zfs-auto-snapshot
)


echo "### Post-boot ZFS config..."
zfs load-key -a
zpool set cachefile=/etc/zfs/zpool.cache boot
zpool set cachefile=/etc/zfs/zpool.cache z
if [[ -d /bulk ]]
then
    zpool set cachefile=/etc/zfs/zpool.cache bulk
fi
zfs mount -a

#/etc/systemd/system/zfs-load-key.service
#/etc/systemd/system/zfs-scrub@.timer
#/etc/systemd/system/zfs-scrub@.service

systemctl enable zfs.target
systemctl enable zfs-import-cache
systemctl enable zfs-mount
systemctl enable zfs-import.target
systemctl enable zfs-load-key.service
systemctl enable zfs-scrub@boot.timer
systemctl enable zfs-scrub@z.timer
if [[ -d /bulk ]]
then
    systemctl enable zfs-scrub@bulk.timer
fi

zgenhostid $(hostid)

zfs create -o mountpoint=/home z/home
zfs create -o mountpoint=/var/lib/docker z/docker

mkinitcpio -p linux

echo "### Installing Packages..."
sed -i 's/#Color/Color/g' /etc/pacman.conf
pacman -S --needed --noconfirm "${PACKAGES[@]}"

echo "### Adding users..."
#/etc/sudoers.d/wheel

useradd -D --shell /bin/zsh

useradd --user-group --create-home --system gustafson
if [[ -d /bulk ]]
then
    chown -R gustafson:gustafson /bulk
    chmod 775 /bulk
    chmod g+s /bulk
    setfacl -d -m group:gustafson:rwx /bulk
fi

for U in Josh "${OTHER_USERS[@]}"
do
    u=$(echo "${U}" | awk '{print tolower($0)}')
    useradd --groups gustafson --user-group --create-home "${u}"
    cat <<EOF | passwd "${u}"
changeme
changeme
EOF
    passwd -e "${u}"
    mkdir -p /home/${u}/Pictures
    if [[ -d /bulk ]]
    then
        ln -s /bulk/Photos/Favorites /home/${u}/Pictures/Favorites
    fi
    #ln -s /beast/Published/Photos /home/${u}/Pictures/Family
    chown -R ${u}:${u} /home/${u}
done
for U in "${OTHER_USERS[@]}"
do
    u=$(echo "${U}" | awk '{print tolower($0)}')
    if [[ -d /bulk ]]
    then
        chown -R ${u}:${u} /bulk/Kids/${U}
        ln -s /bulk/Kids/${U} /home/${u}/Documents
    fi
    chown -R ${u}:${u} /home/${u}
done

zfs create -o canmount=off z/home/josh
for $i in sync steam
do
    zfs create z/home/josh/${i}
    chown josh:josh /home/josh/${i}
done

usermod -a -G wheel josh
mkdir -p /home/josh/.ssh
curl https://github.com/jgus.keys >> /home/josh/.ssh/authorized_keys
chmod 400 /home/josh/.ssh/authorized_keys
chown -R josh:josh /home/josh/.ssh

echo "### Configuring Samba..."
# /etc/samba/smb.conf
#systemctl enable smb.service
mkdir -p /home/josh/.config/systemd/user
cat << EOF >> /home/josh/.config/systemd/user/smbnetfs.service
[Unit]
Description=smbnetfs

[Service]
ExecStart=/usr/bin/smbnetfs %h/smb
ExecStop=/bin/fusermount -u %h/smb

[Install]
WantedBy=default.target
EOF
chown -R josh:josh /home/josh/.config
sudo -u josh systemctl --user enable smbnetfs

echo "### Configuring Sensors..."
sensors-detect --auto

echo "### Configuring Environment..."
cat <<EOF >>/etc/profile
export EDITOR=nano
EOF

echo "### Configuring Docker..."
#/etc/docker/daemon.json
systemctl enable --now docker.service
systemctl enable docker-snapshot.service
docker volume create portainer_data
systemctl enable portainer.service
docker volume create syncthing_config
systemctl enable syncthing.service
usermod -a -G docker josh

echo "### Configuring ZFS Snapshots..."
# /etc/systemd/system/zfs-auto-snapshot-*.service.d

cd /tmp
ZFS_AUTO_SNAPSHOT_VER="1.2.4"
wget "https://github.com/zfsonlinux/zfs-auto-snapshot/archive/upstream/${ZFS_AUTO_SNAPSHOT_VER}.tar.gz"
tar -xf "${ZFS_AUTO_SNAPSHOT_VER}.tar.gz"
cp zfs-auto-snapshot-upstream-${ZFS_AUTO_SNAPSHOT_VER}/src/zfs-auto-snapshot.8 /usr/local/share/man/man8/zfs-auto-snapshot.8
cp zfs-auto-snapshot-upstream-${ZFS_AUTO_SNAPSHOT_VER}/src/zfs-auto-snapshot.sh /usr/bin/zfs-auto-snapshot

zfs set com.sun:auto-snapshot=true boot
zfs set com.sun:auto-snapshot=true z
zfs set com.sun:auto-snapshot=false z/root/var
zfs set com.sun:auto-snapshot=false z/images/scratch
for i in monthly weekly daily hourly frequent
do
    systemctl enable zfs-auto-snapshot-${i}.timer
done


cat <<EOF
#####
#
# Please enter a root password:
#
#####
EOF
passwd

echo "### Cleaning up..."
rm -rf /install
rm /etc/systemd/system/getty@tty1.service.d/override.conf

echo "### Making a snapshot..."
for pool in boot z/root z/home z/docker z/images
do
    zfs snapshot ${pool}@post-boot-install
done

echo "### Done with post-boot install! Rebooting..."
reboot
