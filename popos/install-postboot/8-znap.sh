#!/bin/bash

install zfs-auto-snapshot
# /etc/systemd/system/zfs-auto-snapshot-*.service.d
for i in monthly weekly daily hourly frequent
do
    systemctl enable zfs-auto-snapshot-${i}.timer
done

# TODO - do we need to unhook cron?
