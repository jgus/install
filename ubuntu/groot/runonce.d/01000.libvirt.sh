#!/usr/bin/env bash

set -e

apt -y install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virtinst ovmf ksmtuned virt-manager

zfs create -o mountpoint=/var/lib/libvirt/images user/images
zfs create user/images/scratch
ln -s /usr/local/bin/take-snapshot.sh /var/lib/libvirt/images/take-snapshot.sh

virsh net-define /recovery/setup/libvirt/internal-network.xml
virsh net-autostart internal
virsh net-start internal

for i in Linux macOS
do
    virsh pool-define-as ${i} dir --target /beast/Software/${i}
    virsh pool-autostart ${i}
    virsh pool-start ${i}
done

echo "/var/lib/libvirt/images/** r," >>/etc/apparmor.d/local/abstractions/libvirt-qemu

#echo "options kvm ignore_msrs=1" >> /etc/modprobe.d/kvm.conf

update-grub
update-initramfs -u

rsync -arP /recovery/setup/libvirt/hooks/ /etc/libvirt/hooks

cat <<EOF >/etc/systemd/system/libvirtd-snapshots.service
[Unit]
Description=LibVirt Snapshots
BindsTo=libvirtd.service
Before=libvirtd.service

[Service]
Type=oneshot
ExecStart=/var/lib/libvirt/images/take-snapshot.sh libvirt-up
RemainAfterExit=true
ExecStop=/var/lib/libvirt/images/take-snapshot.sh libvirt-down

[Install]
WantedBy=libvirtd.service
EOF

cat <<EOF >/etc/systemd/system/libvirtd-active.service
[Unit]
Description=LibVirt Active VMs
BindsTo=libvirtd.service
After=libvirtd.service

[Service]
Type=oneshot
ExecStart=/var/lib/libvirt/images/virsh-restore-active.sh
RemainAfterExit=true
ExecStop=/var/lib/libvirt/images/virsh-remember-active.sh

[Install]
WantedBy=libvirtd.service
EOF

systemctl enable libvirtd-snapshots.service
systemctl enable libvirtd-active.service
systemctl daemon-reload

# cat <<EOF >>/etc/systemd/system/libvirtd-keepawake.service
# [Unit]
# Description=Keep Awake while running VMs
# After=libvirtd.service
# Requires=libvirtd.service

# [Service]
# Type=simple
# ExecStart=/bin/systemd-inhibit --what=sleep --why="Libvirtd is running" --who=%U --mode=block sleep infinity

# [Install]
# WantedBy=libvirtd.service
# EOF
# systemctl enable libvirtd-keepawake.service
