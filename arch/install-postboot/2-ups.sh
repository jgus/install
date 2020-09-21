#!/bin/bash
which apcaccess && systemctl enable apcupsd.service || true
