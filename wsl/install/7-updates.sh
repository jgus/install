#!/bin/bash

install unattended-upgrades
patch -i "${SCRIPT_DIR}"/install/7-updates.patch /etc/apt/apt.conf.d/50unattended-upgrades
