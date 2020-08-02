#!/bin/bash -e

[[ -d /root/.secrets ]] || { echo "No secrets found, did you forget to install them?"; exit 1; }

source "$(cd "$(dirname "$0")" ; pwd)"/common.sh "$@"

lscpu | grep GenuineIntel && HAS_INTEL_CPU=1
lscpu | grep AuthenticAMD && HAS_AMD_CPU=1

KERNEL=${KERNEL:-generic}
((HAS_POP_OS)) && KERNEL=generic

PACKAGES=(
    # apt-file software-properties-common
    # linux-${KERNEL} linux-headers-${KERNEL} linux-image-${KERNEL}
    zfsutils-linux zfs-initramfs zsys
    # sysfsutils
    # parted
    # cryptsetup
    # gnupg
    # patch wget
    # zsh
    # nano
    # man
    # ssh
    # curl
    # locales
    # git
    # rsync
    # network-manager
    # rng-tools
    # ntp
    # cifs-utils
    # smbnetfs sshfs fuseiso hfsprogs
    openssh-server
)
if ((HAS_UEFI))
then
    PACKAGES+=(grub-efi-amd64-signed shim-signed)
else
    PACKAGES+=(grub-pc)
fi
((HAS_INTEL_CPU)) && PACKAGES+=(intel-microcode)
((HAS_AMD_CPU)) && PACKAGES+=(amd64-microcode)
# [[ -f /root/.secrets/openldap.env ]] && PACKAGES+=(sssd libpam-sss libnss-sss)

echo "### Installing packages..."
#/etc/apt/sources.list
#/etc/apt/preferences.d
export DEBIAN_FRONTEND=noninteractive
apt update
#apt upgrade --yes
apt install --yes ${APT_EXTRA_ARGS} "${PACKAGES[@]}"
apt purge snapd --yes
#apt autoremove --yes

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

echo "### /tmp..."
cp /usr/share/systemd/tmp.mount /etc/systemd/system/
systemctl enable tmp.mount

echo "### Configuring Network..."
if [[ -f /root/.secrets/wifi.env ]]
then
    source /root/.secrets/wifi.env
    sed -i "s|@PASSWORD@|${PASSWORD}|g" /etc/netplan/99_config.yaml
fi

# echo "### Configuring LDAP auth..."
# pam-auth-update --remove pwquality --package
# if [[ -f /root/.secrets/openldap.env ]]
# then
#     source /root/.secrets/openldap.env
#     echo "ldap_default_authtok = ${LDAP_ADMIN_PASSWORD}" >> /etc/sssd/sssd.conf
#     sed -i "s|^TLS_CACERT*|TLS_CACERT /etc/ssl/certs/ldap.crt|g" /etc/ldap/ldap.conf
#     patch -i /etc/pam.d/common-session.patch /etc/pam.d/common-session
#     systemctl disable sssd-nss.socket
#     systemctl disable sssd-pam.socket
#     systemctl disable sssd-pam-priv.socket
# fi

# if [[ "${NAS_SHARES}" != "" ]] && [[ -f /root/.secrets/nas ]]
# then
#     echo "### Configuring Samba..."
#     mkdir /nas
#     cat <<EOF >>/etc/fstab

# # NAS
# EOF
#     for share in "${NAS_SHARES[@]}"
#     do
#         mkdir /nas/${share}
#         echo "//nas.gustafson.me/${share} /nas/${share} cifs noauto,nofail,x-systemd.automount,x-systemd.requires=network-online.target,x-systemd.device-timeout=30,credentials=/root/.secrets/nas 0 0" >>/etc/fstab
#         # mount /nas/${share}
#     done
# fi

echo "### Installing bootloader..."
mv /etc/default/grub /etc/default/grub.dist
mv /etc/default/grub.new /etc/default/grub
if [[ "${VFIO_IDS}" != "" ]]
then
    sed -i 's|GRUB_CMDLINE_LINUX_DEFAULT="|GRUB_CMDLINE_LINUX_DEFAULT="vfio-pci.ids=${VFIO_IDS} |g' /etc/default/grub
    ((HAS_INTEL_CPU)) && sed -i 's|GRUB_CMDLINE_LINUX_DEFAULT="|GRUB_CMDLINE_LINUX_DEFAULT="intel_iommu=on iommu=pt |g' /etc/default/grub
    ((HAS_AMD_CPU)) && sed -i 's|GRUB_CMDLINE_LINUX_DEFAULT="|GRUB_CMDLINE_LINUX_DEFAULT="amd_iommu=on iommu=pt kvm_amd.npt=1 kvm_amd.avic=1 |g' /etc/default/grub
    for m in vfio vfio_iommu_type1 vfio_virqfd vfio_pci; do echo ${m} >> /etc/initramfs-tools/modules; done
    for m in vfio vfio_iommu_type1 vfio_pci; do echo ${m} >> /etc/modules; done
    echo "softdep nouveau pre: vfio-pci" >> /etc/modprobe.d/nvidia.conf
    echo "softdep nvidia pre: vfio-pci" >> /etc/modprobe.d/nvidia.conf
    echo "softdep nvidia* pre: vfio-pci" >> /etc/modprobe.d/nvidia.conf
    echo "softdep amdgpu pre: vfio-pci" >> /etc/modprobe.d/amdgpu.conf
    echo "options vfio-pci ids=${VFIO_IDS}" >> /etc/modprobe.d/vfio-pci.conf
fi
update-grub
if ((HAS_UEFI))
then
    for d in $(cd /boot; ls efi.*)
    do
        grub-install --efi-directory=/boot/${d} --bootloader-id=${HOSTNAME}.${d} --recheck --no-floppy
    done
    grub-install --efi-directory=/boot/efi --bootloader-id=${HOSTNAME} --recheck --no-floppy
else
    for DEVICE in "${SYSTEM_DEVICES[@]}"
    do
        grub-install --target=i386-pc "${DEVICE}"
    done
fi
update-initramfs -u -k all
systemctl mask grub-initrd-fallback.service

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
