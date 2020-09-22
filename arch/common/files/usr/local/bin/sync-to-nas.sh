#!/bin/bash -e

source "$( dirname "${BASH_SOURCE[0]}" )/functions.sh"

mirror_boot

DATASETS=($(zfs list -o name | grep -v rpool/docker))

for x in "${DATASETS[@]}"
do
    zfs_send_new_snapshots "" ${x} root@nas e/$(hostname)/${x}
done
