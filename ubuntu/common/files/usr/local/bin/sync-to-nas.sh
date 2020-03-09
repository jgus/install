#!/usr/bin/env bash

set -e

source "$( dirname "${BASH_SOURCE[0]}" )/functions.sh"

for bak in /boot/bak*
do
    [ -d "${bak}" ] || continue
    rsync -arPx --delete /boot/ "${bak}"
done
rsync -arPx --delete /boot/ root@nas:/mnt/e/$(hostname)/boot

DATASETS=($(zfs list -o name | grep -v root/docker))

for x in "${DATASETS[@]}"
do
    zfs_send_new_snapshots "" ${x} root@nas e/$(hostname)/${x}
done
