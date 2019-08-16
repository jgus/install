#!/bin/bash
set -e

zfs load-key -a
zpool set cachefile=/etc/zfs/zpool.cache boot
zpool set cachefile=/etc/zfs/zpool.cache z
zfs mount -a

cat <<EOF >>/etc/systemd/system/zfs-load-key.service
[Unit]
Description=Load encryption keys
DefaultDependencies=no
Before=zfs-mount.service
After=zfs-import.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/bash -c '/usr/bin/zfs load-key -a'

[Install]
WantedBy=zfs-mount.service
EOF
systemctl enable zfs.target
systemctl enable zfs-import-cache
systemctl enable zfs-mount
systemctl enable zfs-import.target
systemctl enable zfs-load-key.service

zgenhostid $(hostid)
mkinitcpio -p linux-zen

rm "$0"
zfs snapshot -r boot@first-boot
zfs snapshot -r z@first-boot
reboot
