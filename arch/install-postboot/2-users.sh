#!/bin/bash

USER_SIZE=${USER_SIZE:-1024}

ssh root@jarvis.gustafson.me true

#/etc/sudoers.d/wheel
#/etc/sudoers.d/builder

useradd -D --shell /bin/zsh

rsync -arPz --sparse root@jarvis.gustafson.me:/home/.images/ /home/
mkdir -p /var/lib/systemd/home
mv /home/local.* /var/lib/systemd/home/

systemctl enable --now systemd-homed

# for user in josh melissa kayleigh john william lyra eden hope peter
# do
#     yes ${user} | homectl create ${user} --storage=luks --luks-discard=on --luks-offline-discard=on --disk-size=${USER_SIZE}G
# done

# for user in josh
# do
#     homectl create ${user} --storage=luks --luks-discard=on --luks-offline-discard=on --disk-size=${USER_SIZE}G --image-path=/home/.images/${user}.home
# done

usermod -a -G wheel josh
