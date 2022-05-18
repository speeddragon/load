FROM alpine:3.15

RUN apk update \
    && apk upgrade \
    && apk add wget curl openssl ncurses \
    && tar -zxvf load.tar.gz

ENTRYPOINT ["/load/bin/load", "start"]