#!/usr/bin/env bash

set -e

zfs create -o mountpoint=/var/lib/docker user/docker
ln -s /usr/local/bin/take-snapshot.sh /var/lib/docker/take-snapshot.sh

apt -y install apt-transport-https ca-certificates curl gnupg-agent software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt update
apt -y install docker-ce

cat <<EOF >/etc/systemd/system/docker-snapshots.service
[Unit]
Description=Docker Snapshots
BindsTo=docker.service
Before=docker.service

[Service]
Type=oneshot
ExecStart=/var/lib/docker/take-snapshot.sh docker-up
RemainAfterExit=true
ExecStop=/var/lib/docker/take-snapshot.sh docker-down

[Install]
WantedBy=docker.service
EOF

systemctl enable docker-snapshots.service
systemctl daemon-reload

#docker run hello-world

# docker volume create portainer_data
# docker run --name Portainer --restart always -d -p 9000:9000 -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer

# docker run --rm -v /var/run/docker.sock:/var/run/docker.sock assaflavie/runlike SyncThing
# docker run --name=SyncThing --hostname=groot --env="PUID=1000" --env="PGID=1000" --env="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" --env="PS1=$(whoami)@$(hostname):$(pwd)$ " --env="HOME=/config" --env="TERM=xterm" --volume="/home/josh:/sync/josh" --volume="c6d772a3f392410b14cb14b5a4d96dcf7f7fcc886bfe60f320fbce6f1b12bc92:/config" --volume="b563b4b74ea8a9216a5a2e7dea9393f8db8124e1ca60fa9b3125c73000740d29:/sync" --volume="/config" --volume="/sync" --volume="/sync/josh" --cap-add="AUDIT_WRITE" --cap-add="CHOWN" --cap-add="DAC_OVERRIDE" --cap-add="FOWNER" --cap-add="FSETID" --cap-add="KILL" --cap-add="MKNOD" --cap-add="NET_BIND_SERVICE" --cap-add="NET_RAW" --cap-add="SETFCAP" --cap-add="SETGID" --cap-add="SETPCAP" --cap-add="SETUID" --cap-add="SYS_CHROOT" --cap-drop="AUDIT_CONTROL" --cap-drop="BLOCK_SUSPEND" --cap-drop="DAC_READ_SEARCH" --cap-drop="IPC_LOCK" --cap-drop="IPC_OWNER" --cap-drop="LEASE" --cap-drop="LINUX_IMMUTABLE" --cap-drop="MAC_ADMIN" --cap-drop="MAC_OVERRIDE" --cap-drop="NET_ADMIN" --cap-drop="NET_BROADCAST" --cap-drop="SYSLOG" --cap-drop="SYS_ADMIN" --cap-drop="SYS_BOOT" --cap-drop="SYS_MODULE" --cap-drop="SYS_NICE" --cap-drop="SYS_PACCT" --cap-drop="SYS_PTRACE" --cap-drop="SYS_RAWIO" --cap-drop="SYS_RESOURCE" --cap-drop="SYS_TIME" --cap-drop="SYS_TTY_CONFIG" --cap-drop="WAKE_ALARM" --network=host --restart=always --label build_version="Linuxserver.io version:- v1.0.0-ls1 Build-date:- 2019-01-22T21:29:57+00:00" --label maintainer="sparklyballs" --detach=true linuxserver/syncthing:latest

# docker run --name SyncThing --env="PUID=1000" --env="PGID=1000" -v /home/josh:/sync/josh -v c6d772a3f392410b14cb14b5a4d96dcf7f7fcc886bfe60f320fbce6f1b12bc92:/config -v b563b4b74ea8a9216a5a2e7dea9393f8db8124e1ca60fa9b3125c73000740d29:/sync --network host --restart always -d linuxserver/syncthing
