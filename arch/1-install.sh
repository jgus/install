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

echo "### Creating root keyfile..."
dd bs=1 count=32 if=/dev/urandom of=/root/vkey

echo "### Adding packages..."
PACKAGES=(
    pacman-contrib
)
pacman -Sy --needed --noconfirm "${PACKAGES[@]}"

echo "### Cleaning up prior partitions..."
umount -R /target || true
for d in $(ls /dev/mapper/crypt*); do cryptsetup close ${i} || true; done
rm -rf /target || true

echo "### Cleaning up prior boot entries..."
for i in $(efibootmgr | grep Arch | sed "s/^Boot//" | sed "s/\*.*//")
do
    efibootmgr -B -b ${i}
done
# for i in $(efibootmgr | grep Windows | sed "s/^Boot//" | sed "s/\*.*//")
# do
#     efibootmgr -B -b ${i}
# done

BOOT_DEVS=()
BOOT_IDS=()
LVM_DEVS=()
LVM_IDS=()

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

        parted -s -a optimal "${DEVICE}" -- mkpart boot '0%' "${END1}GiB"
        parted -s "${DEVICE}" -- set 1 esp on
        parted -s -a optimal "${DEVICE}" -- mkpart primary "${END1}GiB" '100%'
        sleep 1
        BOOT_DEVS+=("${DEVICE}-part1")
        BOOT_IDS+=($(blkid ${DEVICE}-part1 -o value -s PARTUUID))
        LVM_DEVS+=("${DEVICE}-part2")
        LVM_IDS+=($(blkid ${DEVICE}-part2 -o value -s PARTUUID))
    done
}

if [[ -f "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/overrides.sh ]]
then
    echo "### Loading overrides..."
    source "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/overrides.sh
fi

echo "### Partitioning..."
do_partition

echo "### Creating LUKS+LVM... (${LVM_DEVS[@]})"
for i in "${!LVM_DEVS[@]}"
do
    cryptsetup --batch-mode luksFormat --sector-size 4096 "${LVM_DEVS[$i]}" "${VKEY_FILE}"
    cryptsetup open -d "${VKEY_FILE}" "${LVM_DEVS[$i]}" crypt${i}
    pvcreate /dev/mapper/crypt${i}
done
vgcreate vg /dev/mapper/crypt*
lvcreate --type thin-pool -n tp -l 95%FREE vg

lvcreate -n root        -V 64G --thinpool tp vg
lvcreate -n var-cache   -V 8G --thinpool tp vg
lvcreate -n var-log     -V 8G --thinpool tp vg
lvcreate -n var-spool   -V 8G --thinpool tp vg
lvcreate -n var-tmp     -V 8G --thinpool tp vg
lvcreate -n home        -V 1T --thinpool tp vg
lvcreate -n home-root   -V 8G --thinpool tp vg
lvcreate -n swap        -V ${SWAP_SIZE}G --thinpool tp vg

for vol in root var-cache var-log var-spool var-tmp home home-root
do
    mkfs.ext4 /dev/vg/${vol}
done
mkswap /dev/vg/swap

rm -rf /target
mkdir /target
mount -o discard /dev/vg/root /target
for d in cache log spool tmp
do
    mkdir -p /target/var/${d}
    mount -o discard /dev/vg/var-${d} /target/var/${d}
done
mkdir -p /target/home
mount -o discard /dev/vg/home /target/home
mkdir -p /target/root
mount -o discard /dev/vg/home-root /target/root
swapon /dev/vg/swap

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

echo "### Configuring fstab..."
genfstab /target >> /target/etc/fstab
echo "" >> /target/etc/fstab
echo "# TMP" >> /target/etc/fstab
echo "tmpfs /tmp tmpfs rw,nodev,nosuid,relatime 0 0" >> /target/etc/fstab

echo "### Copying root files..."
rsync -ar ~/.ssh/ /target/root/.ssh
rsync -ar ~/opt/ /target/root/opt
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
umount -R /target

echo "### Snapshotting..."
for vol in root
do
    lvcreate -pr -s vg/${vol} -n ${vol}.pre-boot-install 
done

echo "### Done installing! Rebooting..."
reboot
