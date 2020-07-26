#!/bin/bash
set -e

source /root/.secrets/nas

SMB_CONF=/etc/samba/smb.conf
mkdir -p /etc/samba

SHARES=(
    Backup
    Media
    Peer
    Photos
    Projects
    Software
    Storage
    Temp
)

SHARES_RO=(
    Brown
)

# Comics -> Media/Comics
# Music -> Media/Music
# Local Backup -> Backup/Local
# Media-Storage -> Media/Storage
# Photos-Incoming -> Photos/Incoming
# Private -> Users/Josh/Private
# Published -> Photos/Published
# Tools -> Storage/Tools

cat << EOF >${SMB_CONF}
[global]
   workgroup = GUSTAFSON
   server string = NAS
   server role = standalone server
   wins support = yes
EOF

for s in "${SHARES[@]}"
do
cat << EOF >>${SMB_CONF}
[${s}]
   path = /shares/${s}
   valid users = ${username}
   public = no
   writable = yes
   veto files = /._*/.DS_Store/.Trashes/.TemporaryItems/
   delete veto files = yes
EOF
done

for s in "${SHARES_RO[@]}"
do
cat << EOF >>${SMB_CONF}
[${s}]
   path = /shares/${s}
   valid users = ${username}
   public = no
   writable = no
   veto files = /._*/.DS_Store/.Trashes/.TemporaryItems/
   delete veto files = yes
EOF
done

docker build -t jgus/samba /usr/local/share/docker/samba
