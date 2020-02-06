#!/usr/bin/env bash

set -e

IDS="1002:67ff,1002:aae0,10de:1b06,10de:10ef"
DRIVERS=(amdgpu nvidiafb nouveau nvidia nvidia_drm)

sed -i -E 's/^GRUB_CMDLINE_LINUX="(.*)"$/GRUB_CMDLINE_LINUX="\1 intel_iommu=on iommu=pt"/g' /etc/default/grub

cat <<EOF >>/etc/modules
vfio
vfio_iommu_type1
vfio_pci
EOF

for driver in "${DRIVERS[@]}"
do
    echo "softdep ${driver} pre: vfio vfio_pci" >> /etc/initramfs-tools/modules
done
cat <<EOF >>/etc/initramfs-tools/modules
vfio
vfio_iommu_type1
vfio_virqfd
options vfio_pci ids=${IDS}
vfio_pci
EOF
for driver in "${DRIVERS[@]}"
do
    echo "${driver}" >> /etc/initramfs-tools/modules
done

echo "options vfio_pci ids=${IDS}" >> /etc/modprobe.d/vfio_pci.conf
for driver in "${DRIVERS[@]}"
do
    echo "softdep ${driver} pre: vfio vfio_pci" >> /etc/modprobe.d/${driver}.conf
done

update-grub
update-initramfs -u
