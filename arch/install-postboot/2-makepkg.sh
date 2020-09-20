#!/bin/bash
sed -i 's/!ccache/ccache/g' /etc/makepkg.conf
cat <<EOF >>/etc/makepkg.conf 
MAKEFLAGS="-j$(nproc)"
BUILDDIR=/tmp/makepkg
EOF
