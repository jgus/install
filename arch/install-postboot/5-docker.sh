#!/bin/bash

HAS_DOCKER=${HAS_DOCKER:-1}

#/etc/docker/daemon.json
if ((HAS_DOCKER))
then
    zfs create -o mountpoint=/var/lib/docker z/docker || true

    for v in $(ssh root@jarvis.gustafson.me zfs list -r -o name -H e/$(hostname)/z/volumes | sed "s.e/$(hostname)/..")
    do
        zfs_send_new_snapshots root@jarvis.gustafson.me e/$(hostname)/${v} "" ${v}
    done

    zfs create -o mountpoint=/var/volumes -o com.sun:auto-snapshot=true z/volumes || zfs set mountpoint=/var/volumes com.sun:auto-snapshot=true z/volumes
    zfs create -o com.sun:auto-snapshot=false z/volumes/scratch || zfs set com.sun:auto-snapshot=false z/volumes/scratch

    install docker
    ((HAS_NVIDIA)) && install nvidia-container-toolkit
    usermod -a -G docker josh
    systemctl enable docker.service
    systemctl enable docker-prune.timer
fi
