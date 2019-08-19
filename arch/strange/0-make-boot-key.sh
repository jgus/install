#!/bin/bash
set -e

dd bs=1 count=28 if=/dev/urandom of=/tmp/keyfile
efivar -n d719b2cb-3d3a-4596-a3bc-dad00e67656f-keyfile -t 7 -w -f /tmp/keyfile
