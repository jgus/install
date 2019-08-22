#!/bin/bash
set -e

TMPFILE=$(mktemp)
dd bs=1 count=28 if=/dev/urandom of="${TMPFILE}"
efivar -n d719b2cb-3d3a-4596-a3bc-dad00e67656f-keyfile -t 7 -w -f "${TMPFILE}"
rm "${TMPFILE}"