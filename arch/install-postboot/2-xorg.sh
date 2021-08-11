#!/bin/bash

XORG_PACKAGES+=(
    # Mesa
    mesa lib32-mesa mesa-demos
    # Xorg
    xorg tigervnc
    # KDE
    plasma-meta kde-applications-meta xdg-user-dirs packagekit-qt5
    qt5-imageformats
    # Color
    displaycal colord colord-kde
    # Wine
    #wine winetricks
    #wine_gecko wine-mono
    # Applications
    clamtk
    code
    firefox
    gparted
    libreoffice-still hunspell hunspell-en_US libmythes mythes-en
    remmina freerdp
    scribus
    speedtest-cli
    # Media
    audacity
    gimp
    mkvtoolnix-cli mkvtoolnix-gui
    rawtherapee hugin perl-image-exiftool digikam
    rhythmbox
    strawberry gstreamer gst-libav gst-plugins-base gst-plugins-good gst-plugins-ugly
    vlc
    youtube-dl
    # Modeling
    blender
    cura
    freecad
    openscad
    prusa-slicer
    # Fonts
    adobe-source-code-pro-fonts
    adobe-source-sans-pro-fonts
    gentium-plus-font
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
    ((HAS_AMD)) && install xf86-video-amdgpu vulkan-radeon lib32-vulkan-radeon

    echo "### Configuring Xorg..."
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
        ;;
    esac

    #systemctl enable xvnc.socket
fi
