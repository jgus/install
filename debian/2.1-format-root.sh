#!/bin/bash
set -e

ROOTNAME=$1
zpool import -R /target -N z
zfs destroy -r z/${ROOTNAME} || true
zfs create -o mountpoint=none z/${ROOTNAME}
zfs set mountpoint=/ z/${ROOTNAME} || true
zpool export z
