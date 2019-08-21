#!/usr/bin/env bash

set -e

apt -y install openssh-server

cat <<EOF >>/etc/ssh/sshd_config
PubkeyAuthentication yes
PasswordAuthentication no
AllowAgentForwarding yes
AllowTcpForwarding yes
EOF

cp /recovery/setup/ssh/ssh_host_* /etc/ssh/
chown root:root /etc/ssh/ssh_host_*
chmod 600 /etc/ssh/ssh_host_*
chmod 644 /etc/ssh/ssh_host_*.pub

service ssh restart
