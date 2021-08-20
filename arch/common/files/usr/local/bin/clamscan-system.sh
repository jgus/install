#!/bin/bash -e

set -o pipefail

EMAIL_TO="j@gustafson.me"

source "$( dirname "${BASH_SOURCE[0]}" )/functions.sh"

mirror_boot

DATASETS=(/ $(btrfs subvolume list / | awk '{print $9}' | grep -v "^\." | sort))

for d in "${DATASETS[@]}"
do
    mkdir -p "/${d}/.clam/"
    btrfs subvolume delete "/${d}/.clam/scanning" >/dev/null 2>&1 || true
    btrfs subvolume snapshot -r "/${d}" "/${d}/.clam/scanning"
done

ANY_INFECTION=0
ANY_ERROR=0
LOG_FILE=/tmp/clamscan.log
: >${LOG_FILE}
CURRENT_LOG_FILE=/tmp/clamscan-current.log

for d in "${DATASETS[@]}"
do
    : >${CURRENT_LOG_FILE}
    echo "" | tee -a ${LOG_FILE}
    echo "" | tee -a ${LOG_FILE}
    echo "# Scanning ${d}..." | tee -a ${LOG_FILE}
    SCANNING_DATE=$(btrfs subvolume show "/${d}/.clam/scanning" | grep "Creation time:" | awk '{print $3 " " $4}')
    if [ -d "/${d}/.clam/lkg" ]
    then
        LKG_DATE=$(btrfs subvolume show "/${d}/.clam/lkg" | grep "Creation time:" | awk '{print $3 " " $4}')
        echo "# Scanning ${d} incrementally from ${LKG_DATE} to ${SCANNING_DATE}..." | tee -a ${LOG_FILE}
        set +e
        OLD_TRANSID=$(btrfs subvolume find-new "/${d}/.clam/lkg" 9999999)
        OLD_TRANSID=${OLD_TRANSID#transid marker was }
        DIFF_FILES_RAW=$(btrfs subvolume find-new "/${d}/.clam/scanning" ${OLD_TRANSID} | awk '{print $17}' | sort -u)
        DIFF_FILES=()
        for f in "${DIFF_FILES_RAW[@]}"
        do
            f=$(echo -en "${f}")
            [[ -s "/${d}/.clam/scanning/${f}" ]] || continue
            DIFF_FILES+=("/${d}/.clam/scanning/${f}")
        done
        if (( ${#DIFF_FILES[@]} ))
        then
            echo "# Scanning ${#DIFF_FILES[@]} files..." | tee -a ${LOG_FILE}
            clamscan -i --follow-dir-symlinks=0 --follow-file-symlinks=0 -f <(for f in "${DIFF_FILES[@]}"; do echo "${f}"; done) 2>&1 | tee -a ${LOG_FILE} ${CURRENT_LOG_FILE}
            RESULT=$?
        else
            echo "# No files changed." | tee -a ${LOG_FILE}
            RESULT=0
        fi
        set -e
    else
        echo "# Scanning ${d} completely as of ${SCANNING_DATE}..." | tee -a ${LOG_FILE}
        set +e
        clamdscan -m --fdpass -i "/${d}/.clam/scanning/" 2>&1 | tee -a ${LOG_FILE} ${CURRENT_LOG_FILE}
        RESULT=$?
        set -e
    fi
    if ((RESULT==2)) && ! grep "ERROR:" ${CURRENT_LOG_FILE}
    then
        RESULT=0
    fi
    case ${RESULT} in
        0)
        echo "### ${d} looks clean" | tee -a ${LOG_FILE}
        btrfs subvolume delete "/${d}/.clam/infected" >/dev/null 2>&1 || true
        btrfs subvolume delete "/${d}/.clam/lkg" >/dev/null 2>&1 || true
        btrfs subvolume snapshot -r "/${d}/.clam/scanning" "/${d}/.clam/lkg"
        btrfs subvolume delete "/${d}/.clam/scanning" >/dev/null 2>&1 || true
        ;;
        1)
        echo "!!! ${d} looks infected!" | tee -a ${LOG_FILE}
        btrfs subvolume delete "/${d}/.clam/infected" >/dev/null 2>&1 || true
        btrfs subvolume snapshot -r "/${d}/.clam/scanning" "/${d}/.clam/infected"
        btrfs subvolume delete "/${d}/.clam/scanning" >/dev/null 2>&1 || true
        ANY_INFECTION=1
        ;;
        *)
        echo "!!! Error trying to scan ${d}!" | tee -a ${LOG_FILE}
        btrfs subvolume delete "/${d}/.clam/scanning" >/dev/null 2>&1 || true
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
    exit 1
fi
