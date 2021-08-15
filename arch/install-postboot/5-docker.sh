#!/bin/bash

HAS_DOCKER=${HAS_DOCKER:-1}

#/etc/docker/daemon.json
if ((HAS_DOCKER))
then
    btrfs subvolume create /var/lib/docker
    btrfs subvolume create /var/volumes
    btrfs subvolume create /var/volumes/scratch

    # TODO: Restore

    install docker
    ((HAS_NVIDIA)) && install nvidia-container-toolkit
    usermod -a -G docker josh
    systemctl enable docker.service
    systemctl enable docker-prune.timer
fi
