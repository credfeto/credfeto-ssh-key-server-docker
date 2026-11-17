FROM alpine:3.24

RUN apk add --no-cache git openssh-client rsync \
    && addgroup -S -g 1654 backup \
    && adduser -S -D -u 1654 -G backup -h /home/backup backup \
    && mkdir -p /work \
    && chown backup:backup /work

COPY --chmod=0755 backup.sh /usr/local/bin/backup.sh

USER 1654:1654
WORKDIR /work

ENTRYPOINT ["/usr/local/bin/backup.sh"]
