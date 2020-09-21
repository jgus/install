#!/bin/bash

# /etc/samba/smb.conf
# /etc/systemd/user/smbnetfs.service
[[ -f /etc/samba/smb.conf ]] && systemctl enable smb.service || true
