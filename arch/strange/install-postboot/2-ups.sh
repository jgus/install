#!/bin/bash
install apcupsd
which apcaccess && systemctl enable apcupsd.service || true
