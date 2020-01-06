#!/bin/bash
set -e

HOSTNAME=$1
DISTRO=$2
source "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/config.env

KERNEL=${KERNEL:-linux}
KEY_FILE=/sys/firmware/efi/efivars/keyfile-77fa9abd-0359-4d32-bd60-28f4e78f784b

for i in "${!SYSTEM_DEVICES[@]}"
do
    SWAP_DEVS+=("${SYSTEM_DEVICES[$i]}-part3")
done

ssh -4 root@beast pwd || (echo "Failed to connect to beast; SSH keys missing?")
ssh -4 root@loki pwd || true

echo "### Importing/mounting filesystems..."
zpool export z || true
umount -Rl /target || true
"$(cd "$(dirname "$0")" ; pwd)"/2.1-format-root.sh "${DISTRO}"
rm -rf /target
zpool import -R /target -l z
mkdir -p /target/etc
echo "z/${DISTRO} / zfs rw,noatime,xattr,noacl 0 0" >> /target/etc/fstab
mkdir -p /target/boot
mount /dev/disk/by-label/BOOT0 /target/boot
echo "LABEL=BOOT0 /boot vfat rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,utf8,errors=remount-ro 0 2" >> /target/etc/fstab
for (( i=1; i<${#SYSTEM_DEVICES[@]}; i++ ));
do
    mkdir -p /target/boot/bak${i}
    mount /dev/disk/by-label/BOOT${i} /target/boot/bak${i}
    echo "LABEL=BOOT${i} /boot/bak${i} vfat rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,utf8,errors=remount-ro 0 2" >> /target/etc/fstab
done
for i in "${!SWAP_DEVS[@]}"
do
    echo "/dev/mapper/swap${i} none swap defaults,discard,pri=100 0 0" >> /target/etc/fstab
done
mkdir -p /target/tmp
mount -t tmpfs tmpfs /target/tmp
echo "tmpfs /tmp tmpfs rw,nodev,nosuid,relatime,size=${TMP_SIZE} 0 0" >> /target/etc/fstab
if [[ "${BULK_DEVICE}" != "" ]]
then
    zpool import -R /target -l bulk
fi

df -h
mount | grep target

case "${DISTRO}" in
    arch)
        # echo "### Updating Pacman mirrors..."
        # curl -s "https://www.archlinux.org/mirrorlist/?country=US&protocol=https&use_mirror_status=on" | sed -e 's/^#Server/Server/' -e '/^#/d' | rankmirrors -n 5 - >/etc/pacman.d/mirrorlist
        
        echo "### Pacstrapping..."
        pacstrap /target base ${KERNEL}
    ;;
    
    debian)
        echo "### Debootstrapping..."
        debootstrap buster /target
    ;;
    
    *)
        echo "!!! Unknown distro ${DISTRO}"
        exit 1
    ;;
esac

echo "### Copying install files..."
mkdir -p /target/install
cp -rf "$(cd "$(dirname "$0")" ; pwd)"/* /target/install

echo "### Copying preset files..."
rsync -ar "$(cd "$(dirname "$0")" ; pwd)"/common/files/ /target
rsync -ar "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/files/ /target

echo "### Copying NVRAM-stored files..."
"$(cd "$(dirname "$0")" ; pwd)/read-secrets.sh" /target/tmp/machine-secrets
rsync -ar /target/tmp/machine-secrets/files/ /target || true

echo "### Configuring openswap hook..."
case "${DISTRO}" in
    arch)
        echo "run_hook () {" >> /target/etc/initcpio/hooks/openswap
        for i in "${!SWAP_DEVS[@]}"
        do
            echo "cryptsetup --cipher=aes-xts-plain64 --key-size=256 --key-file=${KEY_FILE} --allow-discards open --type plain ${SWAP_DEVS[$i]} swap${i}" >> /target/etc/initcpio/hooks/openswap
        done
        echo "}" >> /target/etc/initcpio/hooks/openswap
        cat << EOF >> /target/etc/initcpio/install/openswap
build ()
{
    add_runscript
}
help ()
{
    echo "Opens the swap encrypted partition(s)"
}
EOF
    ;;
    
    debian)
        echo "swap${i} ${SWAP_DEVS[$i]} ${KEY_FILE} plain,cipher=aes-xts-plain64,size=256,discard" >> /etc/crypttab
    ;;
    
    *)
        echo "!!! Unknown distro ${DISTRO}"
        exit 1
    ;;
esac

echo "### Copying root files..."
rsync -ar ~/opt /target/root/
rsync -ar ~/.ssh/ /target/root/opt/dotfiles/ssh

echo "### Running further install in the chroot..."
case "${DISTRO}" in
    arch)
        arch-chroot /target /install/3-install-chroot.sh ${HOSTNAME}
    ;;
    
    debian)
        mount --rbind /dev  /target/dev
        mount --rbind /proc /target/proc
        mount --rbind /sys  /target/sys
        chroot /target /install/3-install-chroot.sh ${HOSTNAME}
    ;;
    
    *)
        echo "!!! Unknown distro ${DISTRO}"
        exit 1
    ;;
esac

echo "### Unmounting..."
umount -R /target
zfs unmount -a

echo "### Snapshotting..."
for pool in z/${DISTRO}
do
    zfs snapshot ${pool}@pre-boot-install
done

echo "### Exporting..."
zpool export -a

echo "### Done installing!"
