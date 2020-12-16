#!/bin/bash -e

for n in $(cd /dev/disk/by-partlabel/; for d in SWAP*; do echo ${d#SWAP}; done)
do
    blkdiscard -f /dev/disk/by-partlabel/SWAP${n} || true
    cryptsetup --cipher=aes-xts-plain64 --key-size=256 --key-file=/dev/urandom --allow-discards open --type plain /dev/disk/by-partlabel/SWAP${n} swap${n}
    mkswap -L SWAP${n} /dev/mapper/swap${n}
    swapon -p 100 /dev/mapper/swap${n}
done
