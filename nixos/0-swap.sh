#!/usr/bin/env -S bash

for d in $(ls /dev/disk/by-partlabel/swap*)
do
    mkswap "${d}"
    swapon "${d}"
done
free -h
