#!/bin/bash
set -e

[[ -d /root/.secrets ]] || { echo "No secrets found, did you forget to install them?"; exit 1; }

HOSTNAME=$1
source "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/config.env

KEY_FILE=${KEY_FILE:-/sys/firmware/efi/vars/keyfile-77fa9abd-0359-4d32-bd60-28f4e78f784b/data}

for i in "${!SYSTEM_DEVICES[@]}"
do
    DEV="${SYSTEM_DEVICES[$i]}-part4"
    if [[ -b "${DEV}" ]]
    then
        SWAP_DEVS+=("${SYSTEM_DEVICES[$i]}-part4")
    fi
done

echo "### Importing/mounting filesystems..."
zpool export -a || true
umount -Rl /target || true
"$(cd "$(dirname "$0")" ; pwd)"/2.1-format-efi.sh "${HOSTNAME}"
"$(cd "$(dirname "$0")" ; pwd)"/2.1-format-boot.sh "${HOSTNAME}"
"$(cd "$(dirname "$0")" ; pwd)"/2.1-format-root.sh "${HOSTNAME}"
rm -rf /target
zpool import -R /target -l root
mkdir -p /target/etc
#echo "root/root / zfs rw,noatime,xattr,noacl 0 0" >> /target/etc/fstab
mkdir -p /target/boot
mount /dev/disk/by-label/BOOT0 /target/boot
echo "LABEL=BOOT0 /boot ext4 rw,relatime,errors=remount-ro 0 2" >> /target/etc/fstab
mkdir -p /target/boot/efi
mount /dev/disk/by-label/EFI0 /target/boot/efi
echo "LABEL=EFI0 /boot/efi vfat rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,utf8,errors=remount-ro 0 2" >> /target/etc/fstab
for (( i=1; i<${#SYSTEM_DEVICES[@]}; i++ ));
do
    mkdir -p /target/boot/bak.${i}
    mount /dev/disk/by-label/BOOT${i} /target/boot/bak.${i}
    echo "LABEL=BOOT${i} /boot/bak.${i} ext4 rw,relatime,errors=remount-ro 0 2" >> /target/etc/fstab
    mkdir -p /target/boot/bak.${i}/efi
    mount /dev/disk/by-label/EFI${i} /target/boot/bak.${i}/efi
    echo "LABEL=EFI${i} /target/boot/bak.${i}/efi vfat rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,utf8,errors=remount-ro 0 2" >> /target/etc/fstab
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

echo "### Debootstrapping..."
debootstrap eoan /target

echo "### Copying install files..."
mkdir -p /target/install
cp -rf "$(cd "$(dirname "$0")" ; pwd)"/* /target/install

echo "### Copying preset files..."
rsync -ar "$(cd "$(dirname "$0")" ; pwd)"/common/files/ /target
rsync -ar "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/files/ /target | true

echo "### Copying secrets..."
mkdir -p /target/root/.secrets
rsync -ar /root/.secrets/ /target/root/.secrets

# echo "### Copying NVRAM-stored files..."
# "$(cd "$(dirname "$0")" ; pwd)/read-secrets.sh" /target/tmp/machine-secrets
# rsync -ar /target/tmp/machine-secrets/files/ /target || true

echo "### Configuring openswap hook..."
for i in "${!SWAP_DEVS[@]}"
do
    echo "swap${i} ${SWAP_DEVS[$i]} ${KEY_FILE} plain,cipher=aes-xts-plain64,size=256,discard" >> /etc/crypttab
done

echo "### Copying root files..."
# rsync -ar ~/opt /target/root/
# rsync -ar ~/.ssh/ /target/root/opt/dotfiles/ssh
rsync -ar ~/.ssh/ /target/root/.ssh

echo "### Running further install in the chroot..."
mount --rbind /dev  /target/dev
mount --rbind /proc /target/proc
mount --rbind /sys  /target/sys
chroot /target /install/3-install-chroot.sh ${HOSTNAME}

echo "### Unmounting..."
mount | grep -v zfs | tac | awk '/\/target/ {print $3}' | xargs -i{} umount -lf {}
zfs unmount -a

echo "### Snapshotting..."
for pool in root/root
do
    zfs snapshot ${pool}@pre-boot-install
done

echo "### Exporting..."
zpool export -a

echo "### Done installing!"
