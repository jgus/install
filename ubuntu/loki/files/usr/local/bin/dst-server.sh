#!/bin/bash -e

mkdir -p ${HOME}/.klei/DoNotStarveTogether

DOCKER_ARGS=(
    -p 10999-11000:10999-11000/udp
    -p 12346-12347:12346-12347/udp
    -v ${HOME}/.klei/DoNotStarveTogether:/data
    -u $(id -u):$(id -g)
    -e UID=$(id -u)
    -e GID=$(id -g)
)

docker run \
    --rm \
    -it \
    ${DOCKER_ARGS[@]} \
    --name dst-server \
    jamesits/dst-server
