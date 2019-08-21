#!/usr/bin/env bash

set -e

apt -y install lm-sensors nvme-cli fancontrol
sensors-detect --auto
