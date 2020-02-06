#!/usr/bin/env bash

set -e

mkswap /dev/vg/swap

cat <<EOF >>/etc/fstab

/dev/vg/swap	none	swap	sw	0	0
EOF

swapon -a

cat <<EOF >/etc/initramfs-tools/conf.d/resume
RESUME=none
EOF

update-initramfs -u
