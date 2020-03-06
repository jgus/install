#!/bin/bash
set -e

TMPFILE=$(mktemp)
dd bs=1 count=32 if=/dev/urandom of="${TMPFILE}"
efivar -n 77fa9abd-0359-4d32-bd60-28f4e78f784b-keyfile -t 7 -w -f "${TMPFILE}"
rm "${TMPFILE}"
