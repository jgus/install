#!/bin/bash
set -e

ROOTNAME=$1
zfs destroy -r z/${ROOTNAME} || true
zfs create -o mountpoint=/ z/${ROOTNAME}
