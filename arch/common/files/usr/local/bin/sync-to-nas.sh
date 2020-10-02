#!/bin/bash -e

source "$( dirname "${BASH_SOURCE[0]}" )/functions.sh"

mirror_boot

DATASETS=($(zfs list -H -o name | grep -v z/docker))

for x in "${DATASETS[@]}"
do
    zfs_send_new_snapshots "" ${x} root@nas e/$(hostname)/${x}
done
