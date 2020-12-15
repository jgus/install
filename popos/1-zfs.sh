#!/bin/bash -e

SCRIPT_DIR="$(cd "$(dirname "$0")" ; pwd)"

HOSTNAME=$1
source "${SCRIPT_DIR}"/${HOSTNAME}/config.env

VKEY_TYPE=${VKEY_TYPE:-efi} # efi|root|prompt
case ${VKEY_TYPE} in
    efi)
        VKEY_FILE=/sys/firmware/efi/vars/keyfile-77fa9abd-0359-4d32-bd60-28f4e78f784b/data
        if [[ ! -f "${VKEY_FILE}" ]]
        then
            echo "### Creating EFI keyfile..."
            TMPFILE=$(mktemp)
            dd bs=1 count=32 if=/dev/urandom of="${TMPFILE}"
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

Z_DEVS=()
for d in /dev/disk/by-partlabel/ZFS*
do
    Z_DEVS+=(/dev/disk/by-partuuid/$(blkid ${d} -o value -s PARTUUID))
done

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

zfs create -o mountpoint=/home z/home
zfs create -o mountpoint=/root z/home/root

zfs create z/root/install

zpool export z
rm -rf /target
zpool import -R /target z -N
zfs load-key -a
zfs mount z/root
zfs mount -a

echo "### Copying system..."
mkdir -p /source
mount /dev/disk/by-partlabel/WIN0 /source
rsync -arP --exclude "lost+found" /source/ /target

echo "### Copying install files..."
rsync -arP "$(cd ${SCRIPT_DIR}; git rev-parse --show-toplevel)"/ /target/install
rsync -arP "${SCRIPT_DIR}"/common/files/ /target
[[ -d "${SCRIPT_DIR}"/"${HOSTNAME}"/files ]] && rsync -arP "${SCRIPT_DIR}"/"${HOSTNAME}"/files/ /target
rsync -arP /root/ /target/root

echo "### Fixing system for ZFS root..."
mount /dev/disk/by-partlabel/BOOT0 /target/boot/efi
mount --rbind /dev  /target/dev
mount --rbind /proc /target/proc
mount --rbind /sys  /target/sys
chroot /target bash -c "DEBIAN_FRONTEND=noninteractive apt install --yes zfsutils-linux zfs-initramfs zfs-dkms"
chroot /target kernelstub -l -o "root=ZFS=z/root"
echo "PARTUUID=$(blkid /dev/disk/by-partlabel/BOOT0 -o value -s PARTUUID)  /boot/efi  vfat  umask=0077  0  0" >/target/etc/fstab

echo "### Hostname..."
echo "${HOSTNAME}" >/target/etc/hostname
cat >/target/etc/hosts <<EOF
127.0.0.1       localhost
::1             localhost
127.0.1.1       ${HOSTNAME}.gustafson.me      ${HOSTNAME}
EOF

echo "### Enabling SSH..."
chroot /target bash -c "DEBIAN_FRONTEND=noninteractive apt install --yes openssh-server"
cat << EOF >>/target/etc/ssh/sshd_config
PasswordAuthentication no
AllowAgentForwarding yes
AllowTcpForwarding yes
EOF

echo "### Nuking old system..."
umount /source
blkdiscard -f /dev/disk/by-partlabel/WIN0

echo "### Unmounting..."
mount | grep -v zfs | tac | awk '/\/target/ {print $3}' | xargs -i{} umount -lf {}
zfs unmount -a

echo "### Snapshotting..."
zfs snapshot z/root@pre-boot-install

echo "### Exporting..."
zpool export -a
