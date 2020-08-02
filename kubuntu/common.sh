HOSTNAME=$1
source "$(cd "$(dirname "$0")" ; pwd)"/${HOSTNAME}/config.env

VKEY_TYPE=${VKEY_TYPE:-efi} # efi|root|prompt
case ${VKEY_TYPE} in
    efi)
        VKEY_FILE=/sys/firmware/efi/vars/keyfile-77fa9abd-0359-4d32-bd60-28f4e78f784b/data
        if [[ ! -f "${VKEY_FILE}" ]]
        then
            TMPFILE=$(mktemp)
            dd bs=1 count=32 if=/dev/urandom of="${TMPFILE}"
            efivar -n 77fa9abd-0359-4d32-bd60-28f4e78f784b-keyfile -t 7 -w -f "${TMPFILE}"
            rm "${TMPFILE}"
        fi
        ;;
    root|prompt)
        VKEY_FILE=/root/vkey
        if [[ ! -f "${VKEY_FILE}" ]]
        then
            dd bs=1 count=32 if=/dev/urandom of=${VKEY_FILE}
        fi
        ;;
    *)
        echo "Bad VKEY_TYPE: ${VKEY_TYPE}"
        exit 1
        ;;
esac
case ${VKEY_TYPE} in
    efi|prompt)
        SWAP_VKEY_FILE=${VKEY_FILE}
        ;;
    root)
        SWAP_VKEY_FILE=/dev/urandom
        ;;
esac

[[ ! -f /tmp/partids ]] || source /tmp/partids

HAS_UEFI=${HAS_UEFI:-1}
[[ -d /sys/firmware/efi/vars ]] || HAS_UEFI=0
