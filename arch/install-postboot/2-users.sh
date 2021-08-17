#!/bin/bash

USER_SIZE=${USER_SIZE:-1024}

ssh root@jarvis.gustafson.me true

#/etc/sudoers.d/wheel
#/etc/sudoers.d/builder

useradd -D --shell /bin/zsh

rsync -arP root@jarvis.gustafson.me:/home/.images/\*.home.zst /home/
(cd /home; for f in *.home.zst; do zstd -d --rm ${f}; done)
mkdir -p /var/lib/systemd/home
rsync -arP root@jarvis.gustafson.me:/home/.images/local.\* /var/lib/systemd/home/

systemctl enable --now systemd-homed

# for user in josh melissa kayleigh john william lyra eden hope peter
# do
#     yes ${user} | homectl create ${user} --storage=luks --luks-discard=on --luks-offline-discard=on --disk-size=${USER_SIZE}G
# done

if false
then
    homectl create josh --storage=luks --luks-discard=on --luks-offline-discard=on --disk-size=16G --fs-type=btrfs
    homectl activate josh
    cp -rv ~/.ssh /home/josh
    mkdir -p /home/josh/.config/libvirt
    echo 'uri_default = "qemu:///system"' >> /home/josh/.config/libvirt/libvirt.conf
    homectl deactivate josh
    zstd -10 -T0 --rsyncable josh.home -o josh.home.zst
    rsync -arP /home/*.home.zst root@jarvis.gustafson.me:/home/.images/
fi

usermod -a -G wheel josh
