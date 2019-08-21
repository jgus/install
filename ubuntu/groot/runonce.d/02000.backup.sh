#!/usr/bin/env bash

set -e

apt -y install pbzip2 kpartx

cat <<EOF >/etc/cron.daily/01-daily-backup
#!/usr/bin/env bash
/usr/local/bin/daily-backup.sh
EOF
chmod a+x /etc/cron.daily/01-daily-backup

cat <<EOF >/etc/cron.weekly/999-reboot
#!/usr/bin/env bash
reboot
EOF
chmod a+x /etc/cron.weekly/999-reboot

cat <<EOF >/etc/systemd/system/boot-snapshot.service
[Unit]
Description=Boot Snapshot
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/take-snapshot.sh boot
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

systemctl enable boot-snapshot.service
systemctl daemon-reload
