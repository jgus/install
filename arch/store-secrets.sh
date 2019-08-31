#!/bin/bash
set -e

SOURCE=$1
[[ "${SOURCE}" != "" ]] || (echo "No source specified"; exit 1)
[[ -d "${SOURCE}" ]] || (echo "Source does not exist"; exit 1)

TMPFILE=$(mktemp)
tar -cv --zstd -f "${TMPFILE}" "${SOURCE}"

efivar -n 77fa9abd-0359-4d32-bd60-28f4e78f784b-machine-secrets -t 7 -w -f "${TMPFILE}"

rm "${TMPFILE}"
