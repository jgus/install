#!/bin/bash
install rng-tools
systemctl enable --now rngd.service
