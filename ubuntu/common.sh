HOSTNAME=$1
source "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/config.env

ZFS_KEY=${ZFS_KEY:-efi} # efi|root|none|prompt
case ${ZFS_KEY} in
    efi)
        KEY_FILE=/sys/firmware/efi/vars/keyfile-77fa9abd-0359-4d32-bd60-28f4e78f784b/data
        if [[ ! -f "${KEY_FILE}" ]]
        then
            TMPFILE=$(mktemp)
            dd bs=1 count=32 if=/dev/urandom of="${TMPFILE}"
            efivar -n 77fa9abd-0359-4d32-bd60-28f4e78f784b-keyfile -t 7 -w -f "${TMPFILE}"
            rm "${TMPFILE}"
        fi
        ;;
    root|prompt)
        KEY_FILE=/zfs-keyfile
        if [[ ! -f "${KEY_FILE}" ]]
        then
            dd bs=1 count=32 if=/dev/urandom of=${KEY_FILE}
        fi
        ;;
    none)
        ;;
    *)
        echo "Bad ZFS_KEY: ${ZFS_KEY}"
        exit 1
        ;;
esac

[[ ! -f /tmp/partids ]] || source /tmp/partids

HAS_UEFI=${HAS_UEFI:-1}
[[ -d /sys/firmware/efi/vars ]] || HAS_UEFI=0
