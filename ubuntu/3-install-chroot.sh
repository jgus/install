#!/bin/bash
set -e

[[ -d /root/.secrets ]] || { echo "No secrets found, did you forget to install them?"; exit 1; }

HOSTNAME=$1
source "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/config.env

lscpu | grep GenuineIntel && HAS_INTEL_CPU=1
lscpu | grep AuthenticAMD && HAS_AMD_CPU=1

KERNEL=${KERNEL:-generic}

PACKAGES+=(
    grub-efi shim
    linux-${KERNEL} linux-headers-${KERNEL} linux-image-${KERNEL}
    zfsutils-linux zfs-initramfs
    cryptsetup
    zsh
    nano
    man
    ssh
    curl
    locales
    git
    rsync
    sssd libpam-sss libnss-sss
    rng-tools
    cifs-utils
    smbnetfs
)
[[ "${HAS_INTEL_CPU}" == "1" ]] && PACKAGES+=(intel-microcode)
[[ "${HAS_AMD_CPU}" == "1" ]] && PACKAGES+=(amd64-microcode)
# TODO

# Password
cat <<EOF | passwd
changeme
changeme
EOF

echo "### Installing pacakages..."
#/etc/apt/sources.list
#ln -s /proc/self/mounts /etc/mtab
apt update
apt upgrade --yes
apt install --yes "${PACKAGES[@]}"
apt remove --yes gnome-initial-setup
apt autoremove --yes

echo "### Configuring clock..."
ln -sf "/usr/share/zoneinfo/${TIME_ZONE}" /etc/localtime
hwclock --systohc

echo "### Configuring locale..."
echo "en_US.UTF-8 UTF-8" >>/etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >/etc/locale.conf

echo "### Configuring hostname..."
echo "${HOSTNAME}" >/etc/hostname
cat <<EOF >/etc/hosts
127.0.0.1 localhost
::1 localhost
127.0.1.1 ${HOSTNAME}.gustafson.me ${HOSTNAME}
EOF

echo "### Enabling SSH..."
cat << EOF >>/etc/ssh/sshd_config
PasswordAuthentication no
AllowAgentForwarding yes
AllowTcpForwarding yes
EOF
systemctl enable ssh

echo "### ZFS..."
#/etc/systemd/system/zfs-load-key.service
#/etc/systemd/system/zfs-scrub@.timer
#/etc/systemd/system/zfs-scrub@.service
zfs load-key -a
for p in $(zpool list -o name -H)
do
    zpool set cachefile=/etc/zfs/zpool.cache "${p}"
done
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

echo "### Configuring Samba..."
mkdir /beast
cat <<EOF >>/etc/fstab

# Beast
EOF
for share in "${BEAST_SHARES[@]}"
do
    mkdir /beast/${share}
    echo "//beast.gustafson.me/${share} /beast/${share} cifs noauto,nofail,x-systemd.automount,x-systemd.requires=network-online.target,x-systemd.device-timeout=30,credentials=/root/.secrets/beast 0 0" >>/etc/fstab
    # mount /beast/${share}
done

echo "### Configuring VFIO..."
if [[ "${VFIO_IDS}" != "" ]]
then
    echo "options vfio_pci ids=${VFIO_IDS}" >> /etc/modprobe.d/vfio.conf
fi

echo "### /tmp..."
cp /usr/share/systemd/tmp.mount /etc/systemd/system/
systemctl enable tmp.mount

echo "### Configuring boot image..."
update-initramfs -u -k all

echo "### Installing bootloader..."
update-grub
grub-install --efi-directory=/boot/efi --bootloader-id=ubuntu --recheck --no-floppy

echo "### Configuring nVidia updates..."
#/etc/pacman.d/hooks/nvidia.hook

echo "### Configuring Zsh..."
chsh -s /bin/zsh

echo "### Configuring LDAP auth..."
source /root/.secrets/openldap.env
echo "ldap_default_authtok = ${LDAP_ADMIN_PASSWORD}" >> /etc/sssd/sssd.conf
sed -i "s|^/etc/ldap/ldap.conf.*|TLS_CACERT /etc/ssl/certs/ldap.crt/|g" /etc/ldap/ldap.conf
patch -i /etc/pam.d/common-session.patch /etc/pam.d/common-session

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
