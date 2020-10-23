#!/bin/bash

ssh root@jarvis.gustafson.me true

source /usr/local/bin/functions.sh
for v in $(ssh root@jarvis.gustafson.me zfs list -r -o name -H e/$(hostname)/z/home | sed "s.e/$(hostname)/.." | grep -v "^z/home$" | grep -v "^z/home/root$")
do
    zfs_send_new_snapshots root@jarvis.gustafson.me e/$(hostname)/${v} "" ${v}
done
for u in $(zfs list -r -o name -H z/home | grep steam | sed "s.z/home/.." | sed "s./steam$..")
do
    zfs set mountpoint=/home/${u}/.local/share/Steam z/home/${u}/steam
done

#/etc/sudoers.d/wheel
#/etc/sudoers.d/builder
patch -i /etc/pam.d/system-login.patch /etc/pam.d/system-login

useradd -D --shell /bin/zsh

while IFS=, read -r user uid
do
    groupadd --gid ${uid} ${user}
    useradd --gid ${uid} --no-create-home --no-user-group --uid ${uid} ${user}
    passwd -l ${user}
done << EOF
josh,2000
melissa,2001
kayleigh,2002
john,2003
william,2004
lyra,2005
eden,2006
hope,2007
peter,2008
gustafson,3000
EOF

/etc/mkhome.sh josh
usermod -a -G wheel josh
mkdir -p /home/josh/.ssh
curl https://github.com/jgus.keys >> /home/josh/.ssh/authorized_keys
chmod 400 /home/josh/.ssh/authorized_keys
chown -R josh:josh /home/josh
