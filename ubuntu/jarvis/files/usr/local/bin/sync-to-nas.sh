#!/usr/bin/env bash

set -e

source "$( dirname "${BASH_SOURCE[0]}" )/functions.sh"

mirror_boot

#DATASETS=($(zfs list -o name | grep -v root/docker))
DATASETS=(bpool rpool)

for x in "${DATASETS[@]}"
do
    zfs_send_new_snapshots "" ${x} "" e/$(hostname)/${x}
done

DATASETS=(bpool rpool)
for s in backup git home photos projects images volumes
do
    DATASETS+=($(zfs list -H -o name -r d/${s}))
done

for x in "${DATASETS[@]}"
do
    zfs_send_new_snapshots "" ${x} "" b/${x}
done

DATASETS=(bpool)
for s in git home
do
    DATASETS+=($(zfs list -H -o name -r d/${s}))
done

for x in "${DATASETS[@]}"
do
    zfs_rclone_backup ${x}
done

# zfs_rclone_restore bpool znap_2022-05-15-0900_daily d/scratch/bpool-test
