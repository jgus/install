#!/usr/bin/env bash

set -e

apt -y install software-properties-common
add-apt-repository universe
add-apt-repository multiverse
apt -y upgrade
