#!/bin/bash
set -e

SOURCE=$1
[[ "${SORUCE}" != "" ]] || (echo "No source specified"; exit 1)
[[ -d "${SORUCE}" ]] || (echo "Source does not exist"; exit 1)

TMPFILE=$(mktemp)
tar -c --zstd -f "${TMPFILE}" "${SORUCE}"

efivar -n d719b2cb-3d3a-4596-a3bc-dad00e67656f-machine-secrets -t 7 -w -f "${TMPFILE}"

rm "${TMPFILE}"