#!/bin/bash
set -e

zpool set cachefile=/etc/zfs/zpool.cache boot
zpool set cachefile=/etc/zfs/zpool.cache z
systemctl enable zfs.target
systemctl enable zfs-import-cache
systemctl enable zfs-mount
systemctl enable zfs-import.target
zgenhostid $(hostid)
mkinitcpio -p linux-zen

rm "$0"

# TODO: snapshot
