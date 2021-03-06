#!/bin/bash

install zsh

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
patch /etc/pam.d/login << EOF
*** login.0     2020-12-14 08:36:50.020380720 -0700
--- login.1     2020-12-14 08:38:01.055445783 -0700
***************
*** 28,29 ****
--- 28,31 ----
  
+ session    required   pam_exec.so debug stdout /usr/local/bin/mkhome.sh
+ 
  # Prints the message of the day upon successful login.
EOF

useradd -D --shell /bin/zsh
chsh -s /bin/zsh

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

/usr/local/bin/mkhome.sh josh
for g in adm sudo
do
    usermod -a -G ${g} josh
done
mkdir -p /home/josh/.ssh
curl https://github.com/jgus.keys >> /home/josh/.ssh/authorized_keys
chmod 400 /home/josh/.ssh/authorized_keys
chown -R josh:josh /home/josh
