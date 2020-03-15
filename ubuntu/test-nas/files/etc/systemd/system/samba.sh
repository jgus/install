#!/bin/bash
set -e

service_name=$1

DOCKER_ARGS=(run --rm --name ${service_name} --net host)
DOCKER_ARGS+=(
    -v /shares:/shares
    --tmpfs /shares/Temp
)
DOCKER_ARGS+=(dperson/samba)
DOCKER_ARGS+=(-n)

source /root/.secrets/beast
DOCKER_ARGS+=(-u ${username};${password};$(/usr/bin/id -u ${username});gustafson;$(/usr/bin/id -g gustafson))

SHARES=(
    Backup
    Media
    Peer
    Photos
    Software
    Storage
    Temp
    Users
)

SHARES_RO=(
    Brown
)

# Comics -> Media/Comics
# Music -> Media/Music
# Local Backup -> Backup/Local
# Media-Storage -> Media/Storage
# Photos-Incoming -> Photos/Incoming
# Private -> Users/Josh/Private
# Published -> Photos/Published
# Tools -> Storage/Tools

for s in "${SHARES[@]}"
do
    DOCKER_ARGS+=(-s ${s};/shares/${s};;;no;$${username};;;)
done

for s in "${SHARES_RO[@]}"
do
    DOCKER_ARGS+=(-s ${s};/shares/${s};;yes;no;$${username};;;)
done

docker "${DOCKER_ARGS[@]}"
