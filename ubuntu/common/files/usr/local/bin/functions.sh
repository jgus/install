#!/usr/bin/env bash

mirror_boot() {
    for bak in /boot/bak*
    do
        [ -d "${bak}" ] || continue
        rsync -arPx --delete /boot/ "${bak}"
        rsync -arPx --delete /boot/efi/ "${bak}"/efi
    done
    rsync -arP --exclude=bak\* --delete /boot/ /boot-mirror
}

zfs_cmd () {
    if [[ "$1" == "" ]]
    then
        echo "zfs"
    else
        echo "ssh $1 zfs"
    fi
}

zfs_list_snapshots () {
    $(zfs_cmd $1) list -H -t snapshot -o name | grep -v @znap_.\*_frequent | grep -v @znap_.\*_hourly | grep -v @clam || true
}

zfs_has_snapshot () {
    local DATASET=$1 ; shift
    local SNAPSHOT=$1 ; shift
    [[ ( "${SNAPSHOT}" == "" ) ]] && return 1
    for EXISTING in "$@"
    do
        [[ "${EXISTING}" == "${DATASET}@${SNAPSHOT}" ]] && return 0
    done
    return 1
}

zfs_send_new_snapshots() {
    local SOURCE_HOST=$1
    local SOURCE_DATASET=$2
    local TARGET_HOST=$3
    local TARGET_DATASET=$4

    local SOURCE_SNAPSHOTS_FULL
    local TARGET_SNAPSHOTS_FULL
    echo "Listing source snapshots from ${SOURCE_DATASET}..."
    SOURCE_SNAPSHOTS_FULL=($(zfs_list_snapshots "${SOURCE_HOST}" | grep ^${SOURCE_DATASET}@ || true))
    echo "Listing target snapshots from ${TARGET_DATASET}..."
    TARGET_SNAPSHOTS_FULL=($(zfs_list_snapshots "${TARGET_HOST}" | grep ^${TARGET_DATASET}@ || true))

    echo "Processing snapshots..."
    local INCREMENTAL=""
    for SNAPSHOT_FULL in "${SOURCE_SNAPSHOTS_FULL[@]}"
    do
        SNAPSHOT=${SNAPSHOT_FULL#${SOURCE_DATASET}@}
        if zfs_has_snapshot "${TARGET_DATASET}" "${SNAPSHOT}" "${TARGET_SNAPSHOTS_FULL[@]}"
        then
            echo "Skipping snapshot ${SNAPSHOT}"
        else
            echo "Sending snapshot (${SOURCE_HOST})${SOURCE_DATASET}@${SNAPSHOT} -> (${TARGET_HOST})${TARGET_DATASET}"
            echo "$(zfs_cmd "${SOURCE_HOST}") send -v ${INCREMENTAL} ${SOURCE_DATASET}@${SNAPSHOT} | $(zfs_cmd "${TARGET_HOST}") receive -F ${TARGET_DATASET}"
            $(zfs_cmd "${SOURCE_HOST}") send -v ${INCREMENTAL} ${SOURCE_DATASET}@${SNAPSHOT} | $(zfs_cmd "${TARGET_HOST}") receive -F ${TARGET_DATASET}
        fi
        INCREMENTAL="-i ${SOURCE_DATASET}@${SNAPSHOT}"
    done

    echo "Done sending ${SOURCE_DATASET}"
}

zfs_rclone_backup() {
    local SOURCE_DATASET=$1

    local SOURCE_SNAPSHOTS_FULL
    local TARGET_SNAPSHOTS_FULL
    echo "Listing source snapshots from ${SOURCE_DATASET}..."
    SOURCE_SNAPSHOTS_FULL=($(zfs_list_snapshots "${SOURCE_HOST}" | grep ^${SOURCE_DATASET}@ || true))
    echo "Listing target snapshots from ${SOURCE_DATASET}..."
    TARGET_SNAPSHOTS_FULL=($(rclone lsf backup-archive:${SOURCE_DATASET}/_/ | sed 's/~.*$//' | awk "{ print \"${SOURCE_DATASET}@\" \$1 }" || true))

    echo "Processing snapshots..."
    local INCREMENTAL=""
    local INCREMENTAL_RCLONE=""
    for SNAPSHOT_FULL in "${SOURCE_SNAPSHOTS_FULL[@]}"
    do
        SNAPSHOT=${SNAPSHOT_FULL#${SOURCE_DATASET}@}
        if zfs_has_snapshot "${SOURCE_DATASET}" "${SNAPSHOT}" "${TARGET_SNAPSHOTS_FULL[@]}"
        then
            echo "Skipping snapshot ${SNAPSHOT}"
        else
            echo "Sending snapshot ${SOURCE_DATASET}@${SNAPSHOT}"
            echo "zfs send -v ${INCREMENTAL} ${SOURCE_DATASET}@${SNAPSHOT} | rclone rcat backup-archive:${SOURCE_DATASET}/_/${SNAPSHOT}${INCREMENTAL_RCLONE}"
            zfs send -v ${INCREMENTAL} ${SOURCE_DATASET}@${SNAPSHOT} | rclone rcat backup-archive:${SOURCE_DATASET}/_/${SNAPSHOT}${INCREMENTAL_RCLONE}
        fi
        INCREMENTAL="-i ${SOURCE_DATASET}@${SNAPSHOT}"
        INCREMENTAL_RCLONE="~${SNAPSHOT}"
    done

    echo "Done sending ${SOURCE_DATASET}"
}

zfs_rclone_restore() {
    local SOURCE_DATASET=$1
    local SNAPSHOT=$2
    local TARGET_DATASET=$3

    if zfs list ${TARGET_DATASET}@${SNAPSHOT} >/dev/null 2>&1
    then
        echo "${TARGET_DATASET}@${SNAPSHOT} exists"
        return 0
    fi

    local SOURCE_SNAPSHOT
    SOURCE_SNAPSHOTS=($(rclone lsf backup-archive:${SOURCE_DATASET}/_/ | grep "^${SNAPSHOT}" || true))

    if (( ${#SOURCE_SNAPSHOTS[@]} == 0 ))
    then
        echo "Couldn't find ${SOURCE_DATASET}@${SNAPSHOT}"
        return 1
    fi

    local SOURCE_SNAPSHOT=${SOURCE_SNAPSHOTS[0]}

    if [[ "${SOURCE_SNAPSHOT}" =~ .*\~.* ]]
    then
        local BASE=${SOURCE_SNAPSHOT##*~}
        echo "Need ${BASE} first"
        zfs_rclone_restore ${SOURCE_DATASET} ${BASE} ${TARGET_DATASET}
    fi

    echo "Restoring ${SOURCE_SNAPSHOT}"
    rclone cat backup-archive:${SOURCE_DATASET}/_/${SOURCE_SNAPSHOT} | zfs receive -F ${TARGET_DATASET}
}

zfs_prune_sent_snapshots() {
    local SOURCE_HOST=$1
    local SOURCE_DATASET=$2
    local TARGET_HOST=$3
    local TARGET_DATASET=$4
    echo "Pruning snapshots from ${SOURCE_HOST}:${SOURCE_DATASET} which have been sent to ${TARGET_HOST}:${TARGET_DATASET}"

    echo "Listing source snapshots..."
    local SOURCE_SNAPSHOTS_FULL
    echo "Listing target snapshots..."
    local TARGET_SNAPSHOTS_FULL
    SOURCE_SNAPSHOTS_FULL=($(zfs_list_snapshots "${SOURCE_HOST}" | grep ^${SOURCE_DATASET}@ || true))
    TARGET_SNAPSHOTS_FULL=($(zfs_list_snapshots "${TARGET_HOST}" | grep ^${TARGET_DATASET}@ || true))

    local PREVIOUS=""
    for SNAPSHOT_FULL in "${SOURCE_SNAPSHOTS_FULL[@]}"
    do
        SNAPSHOT=${SNAPSHOT_FULL#${SOURCE_DATASET}@}
        if ! zfs_has_snapshot "${TARGET_DATASET}" "${SNAPSHOT}" "${TARGET_SNAPSHOTS_FULL[@]}"
        then
            echo "Target doesn't have ${SNAPSHOT}; ending prune"
            return
        fi
        if [[ "${PREVIOUS}" != "" ]]
        then
            echo "Pruning snapshot ${SOURCE_HOST}:${SOURCE_DATASET}@${PREVIOUS}"
            $(zfs_cmd ${SOURCE_HOST}) destroy ${SOURCE_DATASET}@${PREVIOUS}
        fi
        PREVIOUS="${SNAPSHOT}"
    done

    echo "Done pruning ${SOURCE_HOST}:${SOURCE_DATASET}"
}

zfs_prune_empty_snapshots() {
    local HOST=$1
    local DATASET=$2
    echo "Pruning empty snapshots from ${HOST}:${DATASET}"

    echo "Listing snapshots..."
    local SNAPSHOTS_FULL
    SNAPSHOTS_FULL=($(zfs_list_snapshots "${HOST}" | grep ^${DATASET}@ || true))

    local PREVIOUS=""
    for SNAPSHOT_FULL in "${SNAPSHOTS_FULL[@]}"
    do
        if [[ "${PREVIOUS}" != "" ]]
        then
            DIFF=$($(zfs_cmd ${HOST}) diff -H ${PREVIOUS} ${SNAPSHOT_FULL} | wc -l)
            if [[ "${DIFF}" == "0" ]]
            then
                echo "${PREVIOUS} is empty; pruning..."
                $(zfs_cmd ${HOST}) destroy ${PREVIOUS}
            fi
        fi
        PREVIOUS="${SNAPSHOT_FULL}"
    done

    echo "Done pruning snapshots from ${HOST}:${DATASET}"
}
