#!/bin/bash
set -e

zpool set cachefile=/etc/zfs/zpool.cache boot
zpool set cachefile=/etc/zfs/zpool.cache z
zfs mount -a
zgenhostid $(hostid)
mkinitcpio -p linux-zen

rm "$0"
zfs snapshot -r boot@first-boot
zfs snapshot -r z@first-boot
reboot
