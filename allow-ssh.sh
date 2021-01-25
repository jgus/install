#!/bin/bash -e

# bash <(curl -s https://jgus.github.io/install/allow-ssh.sh)

echo "### Setting up SSH..."
mkdir -p ~/.ssh || true
touch ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
curl https://github.com/jgus.keys >> ~/.ssh/authorized_keys
uniq -i ~/.ssh/authorized_keys
chmod 400 ~/.ssh/authorized_keys

echo "### IP Address:"
ip a | grep inet
