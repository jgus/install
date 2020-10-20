#!/bin/bash

if ((HAS_OPTIMUS))
then
    install optimus-manager optimus-manager-qt
    systemctl enable optimus-manager.service

#     cat << EOF >> /etc/X11/xorg.conf.d/10-nvidia-drm-outputclass.conf || true
# Section "OutputClass"
#     Identifier "intel"
#     MatchDriver "i915"
#     Driver "modesetting"
# EndSection

# Section "OutputClass"
#     Identifier "nvidia"
#     MatchDriver "nvidia-drm"
#     Driver "nvidia"
#     Option "AllowEmptyInitialConfiguration"
#     Option "PrimaryGPU" "yes"
#     ModulePath "/usr/lib/nvidia/xorg"
#     ModulePath "/usr/lib/xorg/modules"
# EndSection
# EOF

#     cat << EOF >> /usr/share/sddm/scripts/Xsetup || true
# xrandr --setprovideroutputsource modesetting NVIDIA-0
# xrandr --auto
# xrandr --dpi 96
# EOF

    mkdir -p /lib/udev/rules.d
    cat << EOF > /lib/udev/rules.d/80-nvidia-pm.rules
# Remove NVIDIA USB xHCI Host Controller devices, if present
#ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x0c0330", ATTR{remove}="1"

# Remove NVIDIA USB Type-C UCSI devices, if present
#ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x0c8000", ATTR{remove}="1"

# Remove NVIDIA Audio devices, if present
#ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x040300", ATTR{remove}="1"

# Enable runtime PM for NVIDIA VGA/3D controller devices on driver bind
ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="auto"
ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="auto"

# Disable runtime PM for NVIDIA VGA/3D controller devices on driver unbind
ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="on"
ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="on"
EOF

    cat << EOF > /etc/modprobe.d/nvidia.conf
options nvidia "NVreg_DynamicPowerManagement=0x02"
EOF

    mkdir -p /etc/optimus-manager
    cat << EOF > /etc/optimus-manager/optimus-manager.conf
[optimus]
startup_mode=auto
startup_auto_battery_mode=hybrid
startup_auto_extpower_mode=nvidia
EOF

    /usr/local/bin/update-efiboot.sh
fi
