#!/bin/bash

XORG_PACKAGES+=(
    # Xorg
    xorg tigervnc
    # KDE
    plasma-meta kde-applications-meta xdg-user-dirs packagekit-qt5
    qt5-imageformats
    # Color
    displaycal colord colord-kde
    # Wine
    wine wine_gecko wine-mono winetricks
    # Applications
    firefox
    code
    remmina freerdp
    libreoffice-still hunspell hunspell-en_US libmythes mythes-en
    scribus
    clamtk
    speedtest-cli
    gparted
    # Media
    vlc
    strawberry gstreamer gst-libav gst-plugins-base gst-plugins-good gst-plugins-ugly
    rhythmbox
    mkvtoolnix-cli mkvtoolnix-gui
    youtube-dl
    gimp
    rawtherapee hugin perl-image-exiftool digikam
    audacity
    # Modeling
    openscad
    blender
    prusa-slicer
    cura
    # Fonts
    adobe-source-code-pro-fonts
    adobe-source-sans-pro-fonts
    font-bh-ttf
    gnu-free-fonts
    noto-fonts
    ttf-anonymous-pro
    ttf-bitstream-vera
    ttf-croscore
    ttf-dejavu
    ttf-droid
    ttf-fantasque-sans-mono
    ttf-fira-code
    ttf-fira-mono
    gentium-plus-font
    ttf-hack
    ttf-inconsolata
    ttf-joypixels
    ttf-liberation
    ttf-linux-libertine
    ttf-roboto
    ttf-ubuntu-font-family
)

if ((HAS_GUI))
then
    install "${XORG_PACKAGES[@]}"
    [[ "${USE_DM}" == "sddm" ]] && install sddm sddm-kcm
    [[ "${USE_DM}" == "gdm" ]] && install gdm
    ((HAS_NVIDIA)) && install nvidia-utils lib32-nvidia-utils nvidia-settings opencl-nvidia ocl-icd cuda clinfo

    echo "### Configuring Xorg..."
    ((HAS_OPTIMUS)) && cat << EOF >> /etc/X11/xorg.conf.d/10-nvidia-drm-outputclass.conf || true
Section "OutputClass"
    Identifier "intel"
    MatchDriver "i915"
    Driver "modesetting"
EndSection

Section "OutputClass"
    Identifier "nvidia"
    MatchDriver "nvidia-drm"
    Driver "nvidia"
    Option "AllowEmptyInitialConfiguration"
    Option "PrimaryGPU" "yes"
    ModulePath "/usr/lib/nvidia/xorg"
    ModulePath "/usr/lib/xorg/modules"
EndSection
EOF

    which ratbagd && systemctl enable ratbagd.service || true
    for d in "${SEAT1_DEVICES[@]}"
    do
        loginctl attach seat1 "${d}"
    done

    echo "### Configuring Fonts..."
    ln -sf ../conf.avail/75-joypixels.conf /etc/fonts/conf.d/75-joypixels.conf

    # echo "### Fetching MS Fonts..."
    # scp root@nas:/mnt/d/bulk/Software/MSDN/Windows/WindowsFonts.tar.bz2 /tmp/
    # cd /usr/share/fonts
    # tar xf /tmp/WindowsFonts.tar.bz2
    # chmod 755 WindowsFonts

    echo "### Configuring Display Manager..."
    case ${USE_DM} in
    gdm)
        systemctl enable gdm.service
        ;;
    sddm)
        systemctl enable sddm.service
        ((HAS_OPTIMUS)) && cat << EOF >> /usr/share/sddm/scripts/Xsetup || true
xrandr --setprovideroutputsource modesetting NVIDIA-0
xrandr --auto
xrandr --dpi 96
EOF
        ;;
    esac

    #systemctl enable xvnc.socket
fi
