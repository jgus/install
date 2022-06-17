#!/usr/bin/env -S bash -e

SCRIPT_DIR="$(cd "$(dirname "$0")" ; pwd)"

mountpoint -q /mnt || { echo "!!! Root not mounted at /mnt"; exit 1 }
mountpoint -q /mnt/boot || { echo "!!! Boot not mounted at /mnt/boot"; exit 1 }

echo "### Copying configuration"
rsync -arP ${SCRIPT_DIR}/common/ /mnt
rsync -arP ${SCRIPT_DIR}/${HOSTNAME}/ /mnt
[ -f /root/.ssh/authorized_keys ]
[ -f /root/.ssh/id_rsa-backup ]
rsync -arP /root/.ssh /mnt/root/
chown -R root:root /mnt

echo "### Generating hardware configuration"
nixos-generate-config --root /mnt

echo "### Installing"
nixos-install --no-root-passwd

echo "### Done! Ready to reboot"
