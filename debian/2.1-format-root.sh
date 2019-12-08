#!/bin/bash
set -e

ROOTNAME=$1
zpool import -N z
zfs destroy -r z/${ROOTNAME} || true
zfs create -o mountpoint=/ z/${ROOTNAME}
zpool export z
