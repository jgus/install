#!/bin/bash -e

DUMP_DIR=/var/lib/libvirt/images/dump
mkdir -p "${DUMP_DIR}"

for m in $(virsh list --all --name)
do
    virsh dumpxml ${m} >"${DUMP_DIR}"/domain-${m}.xml
done

for n in $(virsh net-list --all --name)
do
    virsh net-dumpxml ${n} >"${DUMP_DIR}"/network-${n}.xml
done
