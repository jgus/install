#!/bin/bash -e

source "$(cd "$(dirname "$0")" ; pwd)"/common/files/usr/local/bin/functions.sh

HOSTNAME=$1
source "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/config.env

BOOT_SIZE=${BOOT_SIZE:-2}
SWAP_SIZE=${SWAP_SIZE:-$(free --giga | grep \^Mem | awk '{print $2}')}

if [[ "${KERNELS[@]}" == "" ]]
then
    KERNELS=(linux-lts linux)
fi

VKEY_TYPE=${VKEY_TYPE:-efi} # efi|root|prompt
case ${VKEY_TYPE} in
    efi)
        VKEY_FILE=/sys/firmware/efi/efivars/keyfile-77fa9abd-0359-4d32-bd60-28f4e78f784b
        if [[ ! -f "${VKEY_FILE}" ]]
        then
            echo "### Creating EFI keyfile..."
            TMPFILE=$(mktemp)
            dd bs=1 count=28 if=/dev/urandom of="${TMPFILE}"
            efivar -n 77fa9abd-0359-4d32-bd60-28f4e78f784b-keyfile -t 7 -w -f "${TMPFILE}"
            rm "${TMPFILE}"
        fi
        ;;
    root|prompt)
        VKEY_FILE=/root/vkey
        ;;
    *)
        echo "Bad VKEY_TYPE: ${VKEY_TYPE}"
        exit 1
        ;;
esac
case ${VKEY_TYPE} in
    efi|prompt)
        SWAP_VKEY_FILE=${VKEY_FILE}
        ;;
    root)
        SWAP_VKEY_FILE=/dev/urandom
        ;;
esac
((ALLOW_SUSPEND_TO_DISK)) || SWAP_VKEY_FILE=/dev/urandom

echo "### Creating root keyfile..."
dd bs=1 count=32 if=/dev/urandom of=/root/vkey

echo "### Adding packages..."
PACKAGES=(
    pacman-contrib
)
# pacman-key --recv-keys F75D9D76
# pacman-key --lsign-key F75D9D76
# cat << EOF >>/etc/pacman.conf

# [archzfs]
# Server = https://archzfs.com/\$repo/\$arch
# EOF
pacman -Sy --needed --noconfirm "${PACKAGES[@]}"

echo "### Cleaning up prior partitions..."
for d in $(ls /dev/mapper/swap*); do cryptsetup close ${i} || true; done
mount | grep -v zfs | tac | awk '/\/target/ {print $3}' | xargs -i{} umount -lf {}
zfs unmount -a || true
zpool export z || true
zpool destroy z || true
rm -rf /target || true

echo "### Cleaning up prior boot entries..."
for i in $(efibootmgr | grep Arch | sed "s/^Boot//" | sed "s/\*.*//")
do
    efibootmgr -B -b ${i}
done
for i in $(efibootmgr | grep Windows | sed "s/^Boot//" | sed "s/\*.*//")
do
    efibootmgr -B -b ${i}
done

BOOT_DEVS=()
BOOT_IDS=()
Z_DEVS=()
Z_IDS=()
SWAP_DEVS=()
SWAP_IDS=()

do_partition() {
    for DEVICE in "${SYSTEM_DEVICES[@]}"
    do
        echo "### Wiping and re-partitioning ${DEVICE}..."
        blkdiscard -f "${DEVICE}" || true
        wipefs -af "${DEVICE}"
        parted -s "${DEVICE}" -- mklabel gpt
        while [ -L "${DEVICE}-part2" ] ; do : ; done

        TOTAL_SIZE=$(($(blockdev --getsize64 ${DEVICE}) / (1024 * 1024 * 1024)))
        END1=${BOOT_SIZE}
        END2=$((TOTAL_SIZE-SWAP_SIZE))

        parted -s -a optimal "${DEVICE}" -- mkpart primary '0%' "${END1}GiB"
        parted -s "${DEVICE}" -- set 1 esp on
        parted -s -a optimal "${DEVICE}" -- mkpart primary "${END1}GiB" "${END2}GiB"
        parted -s -a optimal "${DEVICE}" -- mkpart primary "${END2}GiB" '100%'
        sleep 1
        BOOT_DEVS+=("${DEVICE}-part1")
        BOOT_IDS+=($(blkid ${DEVICE}-part1 -o value -s PARTUUID))
        Z_DEVS+=("${DEVICE}-part2")
        Z_IDS+=($(blkid ${DEVICE}-part2 -o value -s PARTUUID))
        SWAP_DEVS+=("${DEVICE}-part3")
        SWAP_IDS+=($(blkid ${DEVICE}-part3 -o value -s PARTUUID))
    done
}

if [[ -f "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/overrides.sh ]]
then
    echo "### Loading overrides..."
    source "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/overrides.sh
fi

echo "### Partitioning..."
do_partition

echo "### Creating zpool z... (${Z_DEVS[@]})"
ZPOOL_ARGS=(
    -o ashift=12
    -O acltype=posixacl
    -O relatime=on
    -O xattr=sa
    -O dnodesize=legacy
    -O normalization=formD
    -O canmount=off
    -O aclinherit=passthrough
    -O com.sun:auto-snapshot=true

    -O compression=lz4
)
case ${VKEY_TYPE} in
    efi)
        ZPOOL_ARGS+=(
            -O encryption=aes-256-gcm
            -O keyformat=raw
            -O keylocation=file://${VKEY_FILE}
        )
        ;;
    prompt)
        ZPOOL_ARGS+=(
            -O encryption=aes-256-gcm
            -O keyformat=passphrase
            -O keylocation=prompt
        )
        ;;
    root)
        ;;
esac

zpool create -f "${ZPOOL_ARGS[@]}" -m none -R /target z ${SYSTEM_Z_TYPE} "${Z_DEVS[@]}"

zfs create z/root -o canmount=noauto -o mountpoint=/
zpool set bootfs=z/root z

zfs create -o canmount=off -o com.sun:auto-snapshot=false z/root/var
zfs create z/root/var/cache
zfs create z/root/var/log
zfs create z/root/var/spool
zfs create z/root/var/tmp

for v in $(ssh root@jarvis.gustafson.me zfs list -r -o name -H e/${HOSTNAME}/z/home | sed s.e/${HOSTNAME}/..)
do
    zfs_send_new_snapshots root@jarvis e/${HOSTNAME}/${v} "" ${v}
done

zfs create -o mountpoint=/home z/home || zfs set mountpoint=/home z/home
zfs create -o mountpoint=/root z/home/root || zfs set mountpoint=/root z/home/root

((HAS_DOCKER)) && zfs create -o mountpoint=/var/lib/docker z/docker

for v in $(ssh root@jarvis.gustafson.me zfs list -r -o name -H e/${HOSTNAME}/z/volumes | sed s.e/${HOSTNAME}/..)
do
    zfs_send_new_snapshots root@jarvis e/${HOSTNAME}/${v} "" ${v}
done

zfs create -o mountpoint=/var/volumes -o com.sun:auto-snapshot=true z/volumes || zfs set mountpoint=/var/volumes com.sun:auto-snapshot=true z/volumes
zfs create -o com.sun:auto-snapshot=false z/volumes/scratch || zfs set com.sun:auto-snapshot=false z/volumes/scratch

for v in $(ssh root@jarvis.gustafson.me zfs list -r -o name -H e/${HOSTNAME}/z/images | sed s.e/${HOSTNAME}/..)
do
    zfs_send_new_snapshots root@jarvis e/${HOSTNAME}/${v} "" ${v}
done

zfs create -o mountpoint=/var/lib/libvirt/images -o com.sun:auto-snapshot=true z/images || zfs set mountpoint=/var/lib/libvirt/images com.sun:auto-snapshot=true z/images
zfs create -o com.sun:auto-snapshot=false z/images/scratch || zfs set com.sun:auto-snapshot=false z/images/scratch

zpool export z
rm -rf /target
zpool import -R /target z -N
zfs load-key -a
zfs mount z/root
zfs mount -a

echo "### Formatting BOOT partition(s)... (${BOOT_DEVS[@]})"
for i in "${!BOOT_DEVS[@]}"
do
    mkfs.fat -F 32 -n "BOOT${i}" "${BOOT_DEVS[$i]}"
done
mkdir -p "/target/boot"
mount "${BOOT_DEVS[0]}" "/target/boot"
for (( i=1; i<${#BOOT_DEVS[@]}; i++ ))
do
    mkdir -p "/target/boot.${i}"
    mount "${BOOT_DEVS[$i]}" "/target/boot.${i}"
done

echo "### Mounting tmp..."
mkdir -p /target/tmp
mount -t tmpfs tmpfs /target/tmp

echo "### Done partitioning!"
df -h
mount | grep target

# echo "### TEMP!!!"
# zsh

# echo "### Updating Pacman mirrors..."
# curl -s "https://www.archlinux.org/mirrorlist/?country=US&protocol=https&use_mirror_status=on" | sed -e 's/^#Server/Server/' -e '/^#/d' | rankmirrors -n 5 - >/etc/pacman.d/mirrorlist

echo "### Pacstrapping..."
pacstrap /target base "${KERNELS[@]}" linux-firmware

echo "### Copying install files..."
mkdir -p /target/install
rsync -ar "$(cd "$(dirname "$0")" ; pwd)"/.. /target/install

echo "### Copying preset files..."
rsync -ar "$(cd "$(dirname "$0")" ; pwd)"/common/files/ /target
rsync -ar "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/files/ /target || true

echo "### Copying ZFS files..."
mkdir -p /etc/zfs
zpool set cachefile=/etc/zfs/zpool.cache z
mkdir -p /target/etc/zfs
cp /etc/zfs/zpool.cache /target/etc/zfs/zpool.cache

echo "### Configuring fstab..."
#genfstab -U /target >> /target/etc/fstab
#echo "z/root / zfs rw,noatime,xattr,noacl 0 0" >> /target/etc/fstab
echo "PARTUUID=${BOOT_IDS[0]} /boot vfat rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,utf8,errors=remount-ro 0 2" >> /target/etc/fstab
for (( i=1; i<${#BOOT_DEVS[@]}; i++ ))
do
    echo "PARTUUID=${BOOT_IDS[$i]} /boot.${i} vfat rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,utf8,errors=remount-ro 0 2" >> /target/etc/fstab
done
echo "tmpfs /tmp tmpfs rw,nodev,nosuid,relatime 0 0" >> /target/etc/fstab

echo "### Configuring swap... (${SWAP_DEVS[@]})"
mkdir -p /target/usr/local/bin
echo "#!/bin/bash -e" >/target/usr/local/bin/swapon.sh
echo "#!/bin/bash" >/target/usr/local/bin/swapoff.sh
for i in "${!SWAP_DEVS[@]}"
do
    echo "blkdiscard -f ${SWAP_DEVS[$i]} || true" >>/target/usr/local/bin/swapon.sh
    echo "cryptsetup --cipher=aes-xts-plain64 --key-size=256 --key-file=${SWAP_VKEY_FILE} --allow-discards open --type plain ${SWAP_DEVS[$i]} swap${i}" >>/target/usr/local/bin/swapon.sh
    echo "mkswap -L SWAP${i} /dev/mapper/swap${i}" >>/target/usr/local/bin/swapon.sh
    echo "swapon -p 100 /dev/mapper/swap${i}" >>/target/usr/local/bin/swapon.sh
    echo "swapoff /dev/mapper/swap${i}" >>/target/usr/local/bin/swapoff.sh
    echo "cryptsetup close /dev/mapper/swap${i}" >>/target/usr/local/bin/swapoff.sh
    echo "blkdiscard -f ${SWAP_DEVS[$i]} || true" >>/target/usr/local/bin/swapoff.sh
    echo "mkfs.ntfs -f -L SWAP${i} ${SWAP_DEVS[$i]}" >>/target/usr/local/bin/swapoff.sh
done
chmod a+x /target/usr/local/bin/swapon.sh
chmod a+x /target/usr/local/bin/swapoff.sh

echo "### Copying root files..."
rsync -ar ~/.ssh/ /target/root/.ssh
rsync -ar ~/.secrets/ /target/root/.secrets
cp /root/vkey /target/root/vkey

# echo "### TEMP!!!"
# zsh

echo "### Configuring hostname..."
echo "${HOSTNAME}" >/target/etc/hostname
cat <<EOF >/target/etc/hosts
127.0.0.1 localhost
::1 localhost
127.0.1.1 ${HOSTNAME}.localdomain ${HOSTNAME}
EOF

echo "### Running further install in the chroot..."
arch-chroot /target /install/arch/2-install-chroot.sh

cat <<EOF
#####
#
# Please enter a root password:
#
#####
EOF
passwd --root /target

echo "### Unmounting..."
mount | grep -v zfs | tac | awk '/\/target/ {print $3}' | xargs -i{} umount -lf {}
zfs unmount -a

echo "### Snapshotting..."
for pool in z/root
do
    zfs snapshot ${pool}@pre-boot-install
done

echo "### Exporting..."
zpool export z

echo "### Done installing! Rebooting..."
reboot
