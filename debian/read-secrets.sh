#!/bin/bash
set -e

TARGET=$1
[[ "${TARGET}" != "" ]] || (echo "No target specified"; exit 1)
[[ ! -d "${TARGET}" ]] || (echo "Target already exists"; exit 1)

mkdir "${TARGET}"
dd if=/sys/firmware/efi/efivars/machine-secrets-77fa9abd-0359-4d32-bd60-28f4e78f784b bs=1 skip=4 status=none | tar -xv --zstd -C "${TARGET}" --strip 1
