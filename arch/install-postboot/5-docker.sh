#!/bin/bash

#/etc/docker/daemon.json
if ((HAS_DOCKER))
then
    install docker
    ((HAS_NVIDIA)) && install nvidia-container-toolkit
    usermod -a -G docker josh
    systemctl enable docker.service
    systemctl enable docker-prune.timer
fi
