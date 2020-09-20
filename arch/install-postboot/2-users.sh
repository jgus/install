#!/bin/bash

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

if which virsh
then
    usermod -a -G libvirt josh
    mkdir -p /home/josh/.config/libvirt
    echo 'uri_default = "qemu:///system"' >> /home/josh/.config/libvirt/libvirt.conf
    chown -R josh:josh /home/josh
fi
