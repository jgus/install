#!/bin/bash -e

set -o pipefail

EMAIL_TO="j@gustafson.me"
EXCLUDE_FILES=(
)
SCAN_MOUNT=/mnt/clam-scan
BASE_MOUNT=/mnt/clam-base

source "$( dirname "${BASH_SOURCE[0]}" )/functions.sh"

mirror_boot

#DATASETS=($(zfs list -H -o name -t filesystem | grep -v root/docker))
DATASETS=($(zfs list -H -o name -t filesystem | grep -v \^bpool))

EXCLUDE_ARGS=()
for f in "${EXCLUDE_FILES[@]}"
do
    EXCLUDE_ARGS+=(--exclude=${SCAN_MOUNT}${f})
done

umount ${SCAN_MOUNT} >/dev/null 2>&1 || true
umount ${BASE_MOUNT} >/dev/null 2>&1 || true
for d in "${DATASETS[@]}"
do
    CANMOUNT=$(zfs get -H -o value canmount ${d})
    [[ "${CANMOUNT}" != "off" ]] || continue
    zfs destroy ${d}@clam-scanning >/dev/null 2>&1 || true
    zfs snapshot ${d}@clam-scanning
done

ANY_INFECTION=0
ANY_ERROR=0
LOG_FILE=/tmp/clamscan.log
: >${LOG_FILE}
CURRENT_LOG_FILE=/tmp/clamscan-current.log

for d in "${DATASETS[@]}"
do
    umount ${SCAN_MOUNT} >/dev/null 2>&1 || true
    umount ${BASE_MOUNT} >/dev/null 2>&1 || true
    MOUNTED=$(zfs get -H -o value mounted ${d})
    CANMOUNT=$(zfs get -H -o value canmount ${d})
    MOUNTPOINT=$(zfs get -H -o value mountpoint ${d})
    [[ "${CANMOUNT}" != "off" ]] || continue
    if [[ "${MOUNTED}" != "yes" ]]
    then
        mkdir -p ${BASE_MOUNT}
        mount -t zfs -o ro ${d} ${BASE_MOUNT}
    fi
    mkdir -p ${SCAN_MOUNT}
    mount -t zfs ${d}@clam-scanning ${SCAN_MOUNT}
    : >${CURRENT_LOG_FILE}
    echo "" | tee -a ${LOG_FILE}
    echo "" | tee -a ${LOG_FILE}
    echo "# Scanning ${d}..." | tee -a ${LOG_FILE}
    if zfs list ${d}@clam-lkg >/dev/null 2>&1
    then
        echo "# Scanning ${d} incrementally from $(zfs get -H -o value creation ${d}@clam-lkg) to $(zfs get -H -o value creation ${d}@clam-scanning)..." | tee -a ${LOG_FILE}
        set +e
        DIFF_FILES_RAW=($(zfs diff -H ${d}@clam-lkg ${d}@clam-scanning | grep -v "^-" | sed 's/^R\t.*\t//' | sed 's/^[M\+]\t//' | sed "s|^${MOUNTPOINT}/*|${SCAN_MOUNT}/|"))
        DIFF_FILES=()
        for f in "${DIFF_FILES_RAW[@]}"
        do
            f=$(echo -en "${f}")
            [[ -s "${f}" ]] || continue
            DIFF_FILES+=("${f}")
        done
        if (( ${#DIFF_FILES[@]} ))
        then
            echo "# Scanning ${#DIFF_FILES[@]} files..." | tee -a ${LOG_FILE}
            clamscan -i "${EXCLUDE_ARGS[@]}" --follow-dir-symlinks=0 --follow-file-symlinks=0 -f <(for f in "${DIFF_FILES[@]}"; do echo "${f}"; done) 2>&1 | tee -a ${LOG_FILE} ${CURRENT_LOG_FILE}
            RESULT=$?
        else
            echo "# No files changed." | tee -a ${LOG_FILE}
            RESULT=0
        fi
        set -e
    else
        echo "# Scanning ${d} completely as of $(zfs get -H -o value creation ${d}@clam-scanning)..." | tee -a ${LOG_FILE}
        set +e
        clamdscan -m --fdpass -i "${SCAN_MOUNT}" 2>&1 | tee -a ${LOG_FILE} ${CURRENT_LOG_FILE}
        RESULT=$?
        set -e
    fi
    umount ${SCAN_MOUNT}
    umount ${BASE_MOUNT} >/dev/null 2>&1 || true
    if ((RESULT==2)) && ! grep "ERROR:" ${CURRENT_LOG_FILE}
    then
        RESULT=0
    fi
    case ${RESULT} in
        0)
        echo "### ${d} looks clean" | tee -a ${LOG_FILE}
        zfs destroy ${d}@clam-infected >/dev/null 2>&1 || true
        zfs destroy ${d}@clam-lkg >/dev/null 2>&1 || true
        zfs rename ${d}@clam-scanning ${d}@clam-lkg
        ;;
        1)
        echo "!!! ${d} looks infected!" | tee -a ${LOG_FILE}
        zfs destroy ${d}@clam-infected >/dev/null 2>&1 || true
        zfs rename ${d}@clam-scanning ${d}@clam-infected
        ANY_INFECTION=1
        ;;
        *)
        echo "!!! Error trying to scan ${d}!" | tee -a ${LOG_FILE}
        zfs destroy ${d}@clam-scanning >/dev/null 2>&1 || true
        ANY_ERROR=1
        ;;
    esac
done

SUBJECT=""
if ((ANY_INFECTION))
then
    SUBJECT="ClamAV Infection on $(hostname)"
elif ((ANY_ERROR))
then
    SUBJECT="ClamAV Error on $(hostname)"
fi
if [[ "${SUBJECT}" != "" ]]
then
    (echo "subject: ${SUBJECT}" && uuencode ${LOG_FILE} clamscan.txt) | ssmtp "${EMAIL_TO}"
fi
