#!/bin/bash
set -e

SOURCE=$1
[[ "${SOURCE}" != "" ]] || (echo "No source specified"; exit 1)
[[ -d "${SOURCE}" ]] || (echo "Source does not exist"; exit 1)

TMPFILE=$(mktemp)
tar -cv --zstd -f "${TMPFILE}" "${SOURCE}"

efivar -n d719b2cb-3d3a-4596-a3bc-dad00e67656f-machine-secrets -t 7 -w -f "${TMPFILE}"

rm "${TMPFILE}"
