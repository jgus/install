#!/bin/bash
set -e

zpool import -R /target -l -N root
zfs destroy -r root/root || true
zfs create -o mountpoint=none root/root
zfs set mountpoint=/ root/root || true
zpool export root
