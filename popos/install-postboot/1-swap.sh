#!/bin/bash

swapon.sh
swapoff.sh
systemctl enable --now swap-ntfs
