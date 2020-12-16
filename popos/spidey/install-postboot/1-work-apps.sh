#!/bin/bash

install slack-desktop
DEBS=(
    https://zoom.us/client/latest/zoom_amd64.deb
    https://www.scootersoftware.com/bcompare-4.3.7.25118_amd64.deb
)
install_deb "${DEBS[@]}"

curl -s https://s3.eu-central-1.amazonaws.com/jetbrains-ppa/0xA6E8698A.pub.asc | apt-key add -
echo "deb http://jetbrains-ppa.s3-website.eu-central-1.amazonaws.com bionic main" >/etc/apt/sources.list.d/jetbrains-ppa.list
apt update
install clion

add-apt-repository -y ppa:maarten-fonville/android-studio
apt update
install android-studio
