#
# Dockerfile for samba
#

FROM alpine

RUN apk add --no-cache samba tini

COPY entrypoint.sh /entrypoint.sh

EXPOSE 137/udp \
       138/udp \
       139/tcp \
       445/tcp

ENTRYPOINT ["tini", "--", "/entrypoint.sh"]
CMD []
