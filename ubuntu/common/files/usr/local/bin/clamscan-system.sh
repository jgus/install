#!/bin/bash -e

EMAIL_TO="j@gustafson.me"
EXCLUDE_FILES=(
    /var/lib/flatpak/repo/objects/34/32b76db9f3df9ffb126a55624df56417c367c47d95e3f619585af51e448144.file
    /var/lib/flatpak/runtime/org.gnome.Platform/x86_64/3.34/c177f62da0f4f40cb0ac814f12c1b2d1f36c764a5b54c0466f4858bed56b94c4/files/libexec/installed-tests/gdk-pixbuf/test-images/gif-test-suite/max-width.gif
)
SCAN_MOUNT=/mnt/clam-scan

source "$( dirname "${BASH_SOURCE[0]}" )/functions.sh"

mirror_boot

DATASETS=($(zfs list -H -o name -t filesystem | grep -v root/docker))

EXCLUDE_ARGS=()
for f in "${EXCLUDE_FILES[@]}"
do
    EXCLUDE_ARGS+=(--exclude=${SCAN_MOUNT}${f})
done

umount ${SCAN_MOUNT} >/dev/null 2>&1 || true
for d in "${DATASETS[@]}"
do
    zfs destroy ${d}@clam-scanning >/dev/null 2>&1 || true
    zfs snapshot ${d}@clam-scanning
done

ANY_INFECTION=0
ANY_ERROR=0
LOG_FILE=/tmp/clamscan.log
: >${LOG_FILE}

for d in "${DATASETS[@]}"
do
    umount ${SCAN_MOUNT} >/dev/null 2>&1 || true
    mkdir -p ${SCAN_MOUNT}
    mount -t zfs ${d}@clam-scanning ${SCAN_MOUNT}
    MOUNTPOINT=$(zfs get -H -o value mountpoint ${d})
    echo "# Scanning ${d}..." | tee -a ${LOG_FILE}
    if zfs list ${d}@clam-lkg >/dev/null 2>&1
    then
        echo "# Scanning ${d} incrementally from $(zfs get -H -o value creation ${d}@clam-lkg) to $(zfs get -H -o value creation ${d}@clam-scanning)..." | tee -a ${LOG_FILE}
        set +e
        clamscan -i "${EXCLUDE_ARGS[@]}" -f <(for f in $(zfs diff -H ${d}@clam-lkg ${d}@clam-scanning | grep -v "^-" | sed 's/^R\t.*\t//' | sed 's/^[M\+]\t//' | sed "s|^${MOUNTPOINT}/*||"); do echo "${SCAN_MOUNT}/${f}"; done) | tee -a ${LOG_FILE}
        RESULT=$?
        set -e
    else
        echo "# Scanning ${d} completely as of $(zfs get -H -o value creation ${d}@clam-scanning)..." | tee -a ${LOG_FILE}
        set +e
        clamscan -i "${EXCLUDE_ARGS[@]}" -r "${SCAN_MOUNT}" | tee -a ${LOG_FILE}
        RESULT=$?
        set -e
    fi
    umount ${SCAN_MOUNT}
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
    echo "subject: ${SUBJECT}"| (cat - && uuencode ${LOG_FILE}) | ssmtp "${EMAIL_TO}"
fi
