FROM alpine
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apk/repositories && apk add perl-yaml-tiny po4a
WORKDIR /work

CMD cd translation && po4a -f -v ./po4a.cfg
