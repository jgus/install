#!/bin/bash

USER_SIZE=${USER_SIZE:-1024}

ssh root@jarvis.gustafson.me true

# TODO - restore backup?

#/etc/sudoers.d/wheel
#/etc/sudoers.d/builder

useradd -D --shell /bin/zsh

systemctl enable --now systemd-homed

mkdir -p /home/.images

# for user in josh melissa kayleigh john william lyra eden hope peter
# do
#     yes ${user} | homectl create ${user} --storage=luks --luks-discard=on --luks-offline-discard=on --disk-size=${USER_SIZE}G
# done

for user in josh
do
    homectl create ${user} --storage=luks --luks-discard=on --luks-offline-discard=on --disk-size=${USER_SIZE}G --image-path=/home/.images/${user}.home
done

usermod -a -G wheel josh
homectl activate josh
mkdir -p /home/josh/.ssh
curl https://github.com/jgus.keys >> /home/josh/.ssh/authorized_keys
chmod 400 /home/josh/.ssh/authorized_keys
chown -R josh:josh /home/josh
homectl update josh --ssh-authorized-keys=@/home/josh/.ssh/authorized_keys
