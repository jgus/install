#!/bin/bash -e

lscpu | grep GenuineIntel && HAS_INTEL_CPU=1
lscpu | grep AuthenticAMD && HAS_AMD_CPU=1
lspci | grep NVIDIA && HAS_NVIDIA=1
((HAS_NVIDIA)) && which optimus-manager && HAS_OPTIMUS=1

BOOT_DRIVE=$(mount | grep /boot | cut -f 1 -d ' ' | sed "s|p.$||")
BOOT_PART=$(mount | grep /boot | cut -f 1 -d ' ' | sed "s|^.*p||")

for i in $(efibootmgr | grep Arch | sed "s/^Boot//" | sed "s/\*.*//")
do
    efibootmgr -B -b ${i}
done
rm /boot/*-startup.nsh || true
rm /boot/*-opts.txt || true

KERNEL_PARAMS_PRE=()
((HAS_INTEL_CPU)) && KERNEL_PARAMS_PRE+=(initrd=/intel-ucode.img)
KERNEL_PARAMS_POST+=(loglevel=3)
for dev in $(cd /dev/mapper; ls crypt*)
do
    id=$(blkid -s UUID -o value $(cryptsetup status ${dev} | grep 'device:' | awk '{print $2}'))
    KERNEL_PARAMS_POST+=(cryptdevice=UUID=${id}:${dev} cryptkey=/sys/firmware/efi/efivars/keyfile-77fa9abd-0359-4d32-bd60-28f4e78f784b)
done
KERNEL_PARAMS_POST+=(root=/dev/mapper/crypt0 rw)
((HAS_INTEL_CPU)) && KERNEL_PARAMS_POST+=(intel_iommu=on iommu=pt)
for k in $(cd /boot; ls -1 vmlinuz-* | sed "s.^vmlinuz-..")
do
    for f in "-fallback" ""
    do
        if ((HAS_OPTIMUS))
        then
            for g in "integrated" "hybrid" "nvidia"
            do
                case ${g} in
                    integrated)
                        GRAPHICS_OPTS=(
                            #module_blacklist=i2c_nvidia_gpu,nouveau,nvidia,nvidia-drm,nvidia-modeset
                            # systemd.mask=nvidia-fallback.service
                        )
                        ;;
                    nvidia|hybrid)
                        GRAPHICS_OPTS=(
                            nvidia-drm.modeset=1
                            # systemd.wants=nvidia-fallback.service
                        )
                        ;;
                esac
                GRAPHICS_OPTS+=(optimus-manager.startup=${g})

                ALL_KERNEL_PARAMS="${KERNEL_PARAMS_PRE[@]} initrd=/initramfs-${k}${f}.img ${KERNEL_PARAMS_POST[@]} ${GRAPHICS_OPTS[@]}"
                echo "vmlinuz-${k} ${ALL_KERNEL_PARAMS}" >>/boot/${k}${f}-${g}-startup.nsh
                echo -n " ${ALL_KERNEL_PARAMS}" >>/boot/${k}${f}-${g}-opts.txt
                efibootmgr --verbose --disk ${BOOT_DRIVE} --part ${BOOT_PART} --create --label "Arch Linux (${k}${f} w/ ${g} graphics)" --loader /vmlinuz-${k} --unicode "${ALL_KERNEL_PARAMS}"
            done
        fi

        ALL_KERNEL_PARAMS="${KERNEL_PARAMS_PRE[@]} initrd=/initramfs-${k}${f}.img ${KERNEL_PARAMS_POST[@]}"
        echo "vmlinuz-${k} ${ALL_KERNEL_PARAMS}" >>/boot/${k}${f}-startup.nsh
        echo -n " ${ALL_KERNEL_PARAMS}" >>/boot/${k}${f}-opts.txt
        efibootmgr --verbose --disk ${BOOT_DRIVE} --part ${BOOT_PART} --create --label "Arch Linux (${k}${f})" --loader /vmlinuz-${k} --unicode "${ALL_KERNEL_PARAMS}"
    done
done
