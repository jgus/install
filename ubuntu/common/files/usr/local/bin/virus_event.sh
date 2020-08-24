#!/bin/bash -e

EMAIL_TO="j@gustafson.me"

SUBJECT="Signature ${CLAM_VIRUSEVENT_VIRUSNAME} detected in ${CLAM_VIRUSEVENT_FILENAME} on ${HOSTNAME}"

# send email
(echo "subject: ${SUBJECT}" && /usr/bin/uuencode <(tail -n 50 /var/log/clamav/clamav.log) logtail.txt) | /usr/sbin/ssmtp "${EMAIL_TO}"

echo "${SUBJECT}" | /usr/bin/systemd-cat -t clamav -p emerg
