#!/bin/bash
set -e

echo "### Post-boot ZFS config..."
zfs load-key -a
zpool set cachefile=/etc/zfs/zpool.cache boot
zpool set cachefile=/etc/zfs/zpool.cache z
zfs mount -a

cat <<EOF >>/etc/systemd/system/zfs-load-key.service
[Unit]
Description=Load encryption keys
DefaultDependencies=no
Before=zfs-mount.service
After=zfs-import.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/bash -c '/usr/bin/zfs load-key -a'

[Install]
WantedBy=zfs-mount.service
EOF

cat <<EOF >>/etc/systemd/system/zfs-scrub@.timer
[Unit]
Description=Monthly zpool scrub on %i

[Timer]
OnCalendar=monthly
AccuracySec=1h
Persistent=true

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF >>/etc/systemd/system/zfs-scrub@.service
[Unit]
Description=zpool scrub on %i

[Service]
Nice=19
IOSchedulingClass=idle
KillSignal=SIGINT
ExecStart=/usr/bin/zpool scrub %i
EOF

systemctl enable zfs.target
systemctl enable zfs-import-cache
systemctl enable zfs-mount
systemctl enable zfs-import.target
systemctl enable zfs-load-key.service
systemctl enable zfs-scrub@boot.timer
systemctl enable zfs-scrub@z.timer

zgenhostid $(hostid)

zfs create -o encryption=on -o keyformat=raw -o keylocation=file:///keys/13 -o mountpoint=/home z/home
zfs create -o encryption=on -o keyformat=raw -o keylocation=file:///keys/13 -o mountpoint=/var/lib/docker z/docker

mkinitcpio -p linux-zen

echo "### Installing Packages..."
PACKAGES=(
    # Xorg
    xorg
    # LightDM
    lightdm lightdm-gtk-greeter
    # KDE
    plasma-meta kde-applications-meta xdg-user-dirs
    # Applications
    # google-chrome vlc ffmpeg-full
)
pacman -S --needed --noconfirm "${PACKAGES[@]}"

echo "### Configuring Xorg..."
#cp /usr/share/X11/xorg.conf.d/* /etc/X11/xorg.conf.d/
#nvidia-xconfig
cat <<EOF >/etc/X11/xorg.conf
# nvidia-xconfig: X configuration file generated by nvidia-xconfig
# nvidia-xconfig:  version 430.40

Section "ServerLayout"
    Identifier     "Layout0"
    Screen      0  "Screen0"
    InputDevice    "Keyboard0" "CoreKeyboard"
    InputDevice    "Mouse0" "CorePointer"
EndSection

Section "Files"
EndSection

Section "InputDevice"
    # generated from default
    Identifier     "Mouse0"
    Driver         "mouse"
    Option         "Protocol" "auto"
    Option         "Device" "/dev/psaux"
    Option         "Emulate3Buttons" "no"
    Option         "ZAxisMapping" "4 5"
EndSection

Section "InputDevice"
    # generated from default
    Identifier     "Keyboard0"
    Driver         "kbd"
EndSection

Section "Monitor"
    Identifier     "Monitor0"
    VendorName     "Unknown"
    ModelName      "Unknown"
    Option         "DPMS"
EndSection

Section "Device"
    Identifier     "Device0"
    Driver         "nvidia"
    VendorName     "NVIDIA Corporation"
EndSection

Section "Screen"
    Identifier     "Screen0"
    Device         "Device0"
    Monitor        "Monitor0"
    DefaultDepth    24
    SubSection     "Display"
        Depth       24
    EndSubSection
EndSection
EOF

echo "### Configuring LightDM..."
systemctl enable lightdm.service

echo "### Making a snapshot..."
rm -rf /install
zfs snapshot boot@first-boot
zfs snapshot z@first-boot

echo "### Done with post-boot install! Rebooting..."
reboot
