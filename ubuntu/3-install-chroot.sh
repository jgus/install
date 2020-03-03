#!/bin/bash
set -e

[[ -d /root/.secrets ]] || { echo "No secrets found, did you forget to install them?"; exit 1; }

HOSTNAME=$1
source "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/config.env

lscpu | grep GenuineIntel && HAS_INTEL_CPU=1
lscpu | grep AuthenticAMD && HAS_AMD_CPU=1

KERNEL=${KERNEL:-generic}

HAS_GUI=${HAS_GUI:-1}

PACKAGES+=(
    apt-file
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
    ntp
    cifs-utils
    smbnetfs sshfs fuseiso hfsprogs
    docker.io
    libvirt-clients qemu-system-x86 qemu-utils
    gcc gdb cmake ninja-build
    python python-pip python-virtualenv
    python3 python3-pip python3-virtualenv
    flatpak plasma-discover-flatpak-backend
    speedtest-cli
)
[[ "${HAS_INTEL_CPU}" == "1" ]] && PACKAGES+=(intel-microcode)
[[ "${HAS_AMD_CPU}" == "1" ]] && PACKAGES+=(amd64-microcode)
[[ "${HAS_GUI}" == "1" ]] && PACKAGES+=(
    kubuntu-desktop
    virt-manager
    displaycal colord colord-kde
    playonlinux winetricks
    hugin libimage-exiftool-perl
    openjdk-8-jdk openjdk-14-jdk icedtea-netx
    tigervnc-standalone-server
    #makemkv-bin
)

#bad?
#encfs
#gdm3

echo "### Installing pacakages..."
#/etc/apt/sources.list
#/etc/apt/preferences.d
#add-apt-repository -y ppa:heyarje/makemkv-beta
apt update
apt upgrade --yes
apt install --yes "${PACKAGES[@]}"
#apt remove --yes gnome-initial-setup
apt autoremove --yes
apt-file update
patch -i /etc/apt/apt.conf.d/50unattended-upgrades.patch /etc/apt/apt.conf.d/50unattended-upgrades
rm /etc/apt/apt.conf.d/50unattended-upgrades.patch

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
#/etc/systemd/system/zfs-auto-snapshot-*.service.d
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
for i in monthly weekly daily hourly frequent
do
    systemctl enable zfs-auto-snapshot-${i}.timer
done

echo "### /tmp..."
cp /usr/share/systemd/tmp.mount /etc/systemd/system/
systemctl enable tmp.mount

echo "### Configuring LDAP auth..."
pam-auth-update --remove pwquality --package
source /root/.secrets/openldap.env
echo "ldap_default_authtok = ${LDAP_ADMIN_PASSWORD}" >> /etc/sssd/sssd.conf
sed -i "s|^TLS_CACERT*|TLS_CACERT /etc/ssl/certs/ldap.crt|g" /etc/ldap/ldap.conf
patch -i /etc/pam.d/common-session.patch /etc/pam.d/common-session

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

echo "### Installing bootloader..."
mv /etc/default/grub /etc/default/grub.dist
mv /etc/default/grub.new /etc/default/grub
update-grub
grub-install --efi-directory=/boot/efi --bootloader-id=ubuntu --recheck --no-floppy

echo "### Configuring nVidia updates..."
#/etc/pacman.d/hooks/nvidia.hook

echo "### Configuring Zsh..."
cat << EOF >> /etc/zsh/zprofile
emulate sh -c 'source /etc/profile'
EOF
wget -O /etc/zsh/zshrc https://git.grml.org/f/grml-etc-core/etc/zsh/zshrc
wget -O /etc/skel/.zshrc https://git.grml.org/f/grml-etc-core/etc/skel/.zshrc
cp /etc/skel/.zshrc /root/
chsh -s /bin/zsh
useradd -D --shell /bin/zsh

#echo "### Configuring Environment..."
#/etc/profile.d/editor.sh

echo "### Configuring Docker..."
#/etc/docker/daemon.json
systemctl enable docker-prune.timer

echo "### Configuring KVM..."
cat << EOF >> /etc/libvirt/qemu.conf
nvram = [
    "/usr/share/ovmf/OVMF.fd:/usr/share/ovmf/OVMF_VARS.fd"
]
EOF

echo "### Configuring User Stuff..."
echo "RuntimeDirectorySize=50%" >> /etc/systemd/logind.conf

cat <<EOF
#####
#
# Please enter a root password:
#
#####
EOF
passwd
