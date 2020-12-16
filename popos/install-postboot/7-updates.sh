#!/bin/bash

install unattended-upgrades update-notifier
patch -i "${SCRIPT_DIR}"/install-postboot/7-updates.patch /etc/apt/apt.conf.d/50unattended-upgrades
