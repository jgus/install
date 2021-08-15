#!/bin/bash

HAS_DOCKER=${HAS_DOCKER:-1}

#/etc/docker/daemon.json
if ((HAS_DOCKER))
then
    lvcreate -n docker           -V 1T --thinpool tp vg
    lvcreate -n volumes          -V 1T --thinpool tp vg
    lvcreate -n volumes-scratch  -V 1T --thinpool tp vg
    mkfs.ext4 /dev/vg/docker
    mkfs.ext4 /dev/vg/volumes
    mkfs.ext4 /dev/vg/volumes-scratch
    mkdir -p /var/lib/docker
    mount -o discard /dev/vg/docker /var/lib/docker
    mkdir -p /var/volumes
    mount -o discard /dev/vg/volumes /var/volumes
    mkdir -p /var/volumes/scratch
    mount -o discard /dev/vg/volumes-scratch /var/volumes/scratch
cat <<EOF >>/etc/fstab

# Docker
/dev/vg/docker           /var/lib/docker         ext4    rw,relatime,discard,stripe=16   0   2
/dev/vg/volumes          /var/volumes            ext4    rw,relatime,discard,stripe=16   0   2
/dev/vg/volumes-scratch  /var/volumes/scratch    ext4    rw,relatime,discard,stripe=16   0   2
EOF

    # TODO: Restore

    install docker
    ((HAS_NVIDIA)) && install nvidia-container-toolkit
    usermod -a -G docker josh
    systemctl enable docker.service
    systemctl enable docker-prune.timer
fi
