#!/bin/bash
set -e

TARGET=$1
[[ "${TARGET}" != "" ]] || (echo "No target specified"; exit 1)
[[ ! -d "${TARGET}" ]] || (echo "Target already exists"; exit 1)

mkdir "${TARGET}"
dd if=/sys/firmware/efi/efivars/machine-secrets-d719b2cb-3d3a-4596-a3bc-dad00e67656f bs=1 skip=4 status=none | tar -x -C "${TARGET}" --strip 1
