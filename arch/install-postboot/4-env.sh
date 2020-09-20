#!/bin/bash
cat <<EOF >>/etc/profile
export EDITOR=nano
alias yay='sudo -u builder yay'
alias yayinst='sudo -u builder yay -Syu --needed'
EOF
