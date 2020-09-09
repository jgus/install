#!/bin/bash -e

mkdir -p ${HOME}/.minecraft/server

DOCKER_ARGS=(
    -e EULA=TRUE
    -e INIT_MEMORY=1G
    -e MAX_MEMORY=8G
    -p 25565:25565
    -p 8123:8123
    -v /etc/timezone:/etc/timezone:ro
    -v ${HOME}/.minecraft/server:/data
    -u $(id -u):$(id -g)
    -e UID=$(id -u)
    -e GID=$(id -g)
)
DOCKER_ARGS+=(
#    -e TYPE=BUKKIT
    -e TYPE=PAPER
)

while [[ $# -gt 0 ]]
do
    case "$1" in
        -v|--version)
        shift
        DOCKER_ARGS+=(-e VERSION=$1)
        shift
        ;;
        *)
        echo "Unknown argument $1:"
        echo "-v|--version <version>       Load a specific version"
        exit 1
        ;;
    esac
done

docker run \
    --rm \
    -it \
    ${DOCKER_ARGS[@]} \
    --name minecraft-server \
    itzg/minecraft-server
