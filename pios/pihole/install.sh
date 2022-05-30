#!/usr/bin/env -S bash -e

SCRIPT_DIR="$(cd "$(dirname "$0")" ; pwd)"

rsync -arP "${SCRIPT_DIR}"/ $1:~/install
ssh $1 "sudo ~/install/install-local.sh"
