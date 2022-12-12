FROM alpine:3.16
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apk/repositories && apk add perl-yaml-tiny po4a
# RUN apk add perl-yaml-tiny po4a
WORKDIR /work

CMD rm -rf translation/src && cp -r src translation/src && cd translation && po4a -f -v ./po4a.cfg
