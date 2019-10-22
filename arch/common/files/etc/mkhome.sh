#!/bin/bash

[[ -d "/home/${CRYPT_USER}" ]] && exit 0

zfs create -o com.sun:auto-snapshot=true z/home/${CRYPT_USER}
for i in .cache sync steam
do
    zfs create -o com.sun:auto-snapshot=false z/home/${CRYPT_USER}/${i}
done
rsync -arP /etc/skel/ z/home/${CRYPT_USER}
mkdir -p /home/${CRYPT_USER}/.config/systemd/user
mkdir -p /home/${CRYPT_USER}/Pictures
ln -s /beast/Published/Photos /home/${CRYPT_USER}/Pictures/Family
if [[ -d /bulk ]]
then
    ln -s /bulk/Photos/Favorites /home/${CRYPT_USER}/Pictures/Favorites
    DOCS=$(find /bulk/Kids -maxdepth 1 -iname ${CRYPT_USER})
    [[ -d "${DOCS}" ]] && ln -s "${DOCS}" /home/${CRYPT_USER}/Documents
fi
chown -R ${CRYPT_USER}:${CRYPT_USER} /home/${CRYPT_USER}
