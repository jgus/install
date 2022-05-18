#!/usr/bin/env -S bash -e

git config --global init.defaultBranch main
git config --global user.email root@localhost
git config --global user.name root
cd /etc/nixos
git init
git add .
git commit -m init
