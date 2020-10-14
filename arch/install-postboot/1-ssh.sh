#!/bin/bash
install openssh
cat << EOF >>/etc/ssh/sshd_config
PasswordAuthentication no
AllowAgentForwarding yes
AllowTcpForwarding yes
EOF
systemctl enable --now sshd.service
