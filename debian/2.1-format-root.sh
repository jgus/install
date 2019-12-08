#!/bin/bash
set -e

KEY_FILE=/sys/firmware/efi/efivars/keyfile-77fa9abd-0359-4d32-bd60-28f4e78f784b

ROOTNAME=$1
zpool import -N z
zfs destroy -r z/${ROOTNAME} || true
zfs create -o encryption=on -o keyformat=raw -o keylocation=file://${KEY_FILE} -o mountpoint=none z/${ROOTNAME}
zfs set mountpoint=/ z/${ROOTNAME} || true
zpool export z
