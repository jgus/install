#!/bin/bash
set -e

[[ -d /root/.secrets ]] || { echo "No secrets found, did you forget to install them?"; exit 1; }

HOSTNAME=$1
source "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/config.env
source /tmp/partids

KEY_FILE=${KEY_FILE:-/sys/firmware/efi/vars/keyfile-77fa9abd-0359-4d32-bd60-28f4e78f784b/data}

echo "### Importing/mounting filesystems..."
zpool export -a || true
umount -Rl /target || true
if ((HAS_UEFI))
then
    "$(cd "$(dirname "$0")" ; pwd)"/2.1-format-efi.sh "${HOSTNAME}"
fi
"$(cd "$(dirname "$0")" ; pwd)"/2.1-format-boot.sh "${HOSTNAME}"
"$(cd "$(dirname "$0")" ; pwd)"/2.1-format-root.sh "${HOSTNAME}"
rm -rf /target
zpool import -R /target -l root
mkdir -p /target/etc
#echo "root / zfs rw,noatime,xattr,noacl 0 0" >> /target/etc/fstab
mkdir -p /target/boot
zpool import -R /target -l boot
if ((HAS_UEFI))
then
    mkdir -p /target/boot/efi
    mount /dev/disk/by-partuuid/${EFI_IDS[0]} /target/boot/efi
    echo "UUID=$(blkid /dev/disk/by-partuuid/${EFI_IDS[0]} -o value -s PARTUUID) /boot/efi vfat rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,utf8,errors=remount-ro 0 2" >> /target/etc/fstab
    for (( i=1; i<${#SYSTEM_DEVICES[@]}; i++ ))
    do
        mkdir -p /target/boot/efi.${i}
        mount /dev/disk/by-partuuid/${EFI_IDS[$i]} /target/boot/efi.${i}
        echo "UUID=$(blkid /dev/disk/by-partuuid/${EFI_IDS[$i]} -o value -s PARTUUID) /boot/efi.${i} vfat rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,utf8,errors=remount-ro 0 2" >> /target/etc/fstab
    done
fi
for p in /dev/mapper/${HOSTNAME}-swap-*
do
    echo "${p} none swap defaults,discard,pri=100 0 0" >> /target/etc/fstab
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

echo "### Debootstrapping..."
debootstrap focal /target

echo "### Copying install files..."
mkdir -p /target/install
cp -rf "$(cd "$(dirname "$0")" ; pwd)"/* /target/install

echo "### Copying preset files..."
rsync -ar "$(cd "$(dirname "$0")" ; pwd)"/common/files/ /target
rsync -ar "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/files/ /target | true

echo "### Copying secrets..."
mkdir -p /target/root/.secrets
rsync -ar /root/.secrets/ /target/root/.secrets

echo "### Configuring openswap hook..."
for i in "${!SWAP_IDS[@]}"
do
    echo "${HOSTNAME}-swap-${i} /dev/disk/by-partuuid/${SWAP_IDS[$i]} ${KEY_FILE} plain,cipher=aes-xts-plain64,size=256,discard" >> /target/etc/crypttab
done

echo "### Copying root files..."
# rsync -ar ~/opt /target/root/
# rsync -ar ~/.ssh/ /target/root/opt/dotfiles/ssh
rsync -ar ~/.ssh/ /target/root/.ssh
[[ "${KEY_FILE}" =~ ^/sys/ ]] || cp ${KEY_FILE} /target/${KEY_FILE}

echo "### Running further install in the chroot..."
mount --rbind /dev  /target/dev
mount --rbind /proc /target/proc
mount --rbind /sys  /target/sys
chroot /target /install/3-install-chroot.sh ${HOSTNAME}

echo "### Unmounting..."
mount | grep -v zfs | tac | awk '/\/target/ {print $3}' | xargs -i{} umount -lf {}
zfs unmount -a

echo "### Snapshotting..."
for pool in root
do
    zfs snapshot ${pool}@pre-boot-install
done

echo "### Exporting..."
zpool export -a

echo "### Done installing!"
