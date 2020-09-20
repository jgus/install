#!/bin/bash

#/etc/docker/daemon.json
if ((HAS_DOCKER))
then
    usermod -a -G docker josh
    systemctl enable docker.service
    systemctl enable docker-prune.timer
fi
