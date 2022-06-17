#!/usr/bin/env -S bash -e

SCRIPT_DIR="$(cd "$(dirname "$0")" ; pwd)"

HOSTNAME=$1

mountpoint -q /mnt || ( echo "!!! Root not mounted at /mnt"; exit 1 )
mountpoint -q /mnt/boot || ( echo "!!! Boot not mounted at /mnt/boot"; exit 1 )

echo "### Copying configuration"
rsync -arP ${SCRIPT_DIR}/common/ /mnt
rsync -arP ${SCRIPT_DIR}/${HOSTNAME}/ /mnt
[ -f /root/.ssh/authorized_keys ] || ( echo "!!! Missing /root/.ssh/authorized_keys"; exit 1 )
[ -f /root/.ssh/id_rsa-backup ] || ( echo "!!! Missing /root/.ssh/id_rsa-backup"; exit 1 )
rsync -arP /root/.ssh /mnt/root/
chown -R root:root /mnt

echo "### Generating hardware configuration"
nixos-generate-config --root /mnt
sed -i 's/fsType = "zfs"/fsType = "zfs"; options = [ "zfsutil" ]/' /mnt/etc/nixos/hardware-configuration.nix

echo "### Installing"
nixos-install --no-root-passwd

echo "### Done! Ready to reboot"
