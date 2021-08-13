#!/bin/bash
install openssh
cat << EOF >>/etc/ssh/sshd_config
PasswordAuthentication yes
AllowAgentForwarding yes
AllowTcpForwarding yes

AuthenticationMethods publickey,password
AuthorizedKeysCommand /usr/bin/userdbctl ssh-authorized-keys %u
AuthorizedKeysCommandUser root
EOF
systemctl enable --now sshd.service
