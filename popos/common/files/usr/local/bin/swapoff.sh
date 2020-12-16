#!/bin/bash

for n in $(cd /dev/disk/by-partlabel/; for d in SWAP*; do echo ${d#SWAP}; done)
do
    swapoff /dev/mapper/swap${n}
    cryptsetup close /dev/mapper/swap${n}
    blkdiscard -f /dev/disk/by-partlabel/SWAP${n} || true
    mkfs.ntfs -f -L SWAP${n} /dev/disk/by-partlabel/SWAP${n}
done
