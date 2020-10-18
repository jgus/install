#!/bin/bash
install ntp
ntpd -q -n -u ntp:ntp
systemctl enable --now ntpd.service
