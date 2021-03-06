#!/bin/bash

USER=${1:-${PAM_USER}}
HOME_DIR=$(eval echo ~${USER})
HOME_DIR=${HOME_DIR%/}

[[ -d "${HOME_DIR}" ]] && exit 0

zfs create -o mountpoint="${HOME_DIR}" -o com.sun:auto-snapshot=true z/home/${USER}
for i in .cache steam
do
    zfs create -o com.sun:auto-snapshot=false z/home/${USER}/${i}
done
zfs set mountpoint="${HOME_DIR}"/.local/share/Steam z/home/${USER}/steam

rsync -arP /etc/skel/ ${HOME_DIR}
if [[ -d /nas/Published ]]
then
    mkdir -p ${HOME_DIR}/Pictures
    ln -s /nas/Published/Photos ${HOME_DIR}/Pictures/Family
fi
if [[ -d /win/data/Sync ]]
then
    ln -s /win/data/Sync ${HOME_DIR}/sync
fi
if [[ -d /bulk ]]
then
    mkdir -p ${HOME_DIR}/Pictures
    ln -s /bulk/Photos/Favorites ${HOME_DIR}/Pictures/Favorites
    DOCS=$(find /bulk/Kids -maxdepth 1 -iname ${USER})
    [[ -d "${DOCS}" ]] && ln -s "${DOCS}" ${HOME_DIR}/Documents
fi
chown -R ${USER}:${USER} ${HOME_DIR}

#sudo -u ${USER} systemctl --user enable --now hometmp.service
