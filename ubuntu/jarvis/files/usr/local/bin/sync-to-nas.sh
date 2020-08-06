#!/usr/bin/env bash

set -e

source "$( dirname "${BASH_SOURCE[0]}" )/functions.sh"

for bak in /boot/bak*
do
    [ -d "${bak}" ] || continue
    rsync -arPx --delete /boot/ "${bak}"
done
rsync -arPx --delete /boot/ /e/$(hostname)/boot

#DATASETS=($(zfs list -o name | grep -v rpool/docker))
DATASETS=(rpool)

for x in "${DATASETS[@]}"
do
    zfs_send_new_snapshots "" ${x} "" e/$(hostname)/${x}
done

DATASETS=(rpool)
for s in backup git home photos projects images volumes
do
    DATASETS+=($(zfs list -H -o name -r d/${s}))
done

for x in "${DATASETS[@]}"
do
    zfs_send_new_snapshots "" ${x} "" b/${x}
done
